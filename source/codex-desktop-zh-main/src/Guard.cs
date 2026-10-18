using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;

namespace CodexZhLauncher
{
    /// <summary>
    /// 守护模式：开机后在后台静默常驻。
    /// 用户照常点击原版 Codex 图标时，Codex 是"裸启动"（没有调试端口，无法注入），
    /// 守候进程会检测到这种外部实例，静默接管并重启成中文界面。
    ///
    /// 性能设计：
    ///  - 自己拉起的实例存活时，每 2 秒只做一次 GetProcessById 存活检查，不做任何扫描；
    ///  - 没有 Codex 进程时，只按名字做轻量枚举；
    ///  - 只有真的发现"外来实例"时，才执行一次耗时的包检测（会调 PowerShell）。
    /// </summary>
    internal static class Guard
    {
        private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(1);
        private static readonly TimeSpan DetectCooldown = TimeSpan.FromSeconds(30);
        private static readonly TimeSpan AutoLaunchDelay = TimeSpan.FromSeconds(1);
        private const string MutexName = @"Local\CodexZhLauncherGuard";
        private static readonly int CurrentSessionId = Process.GetCurrentProcess().SessionId;

        public static int Run()
        {
            bool createdNew;
            using (var mutex = new Mutex(true, MutexName, out createdNew))
            {
                if (!createdNew)
                {
                    AppLog.Write("guard.already-running");
                    return 0;
                }

                AppLog.Write("guard.start");
                AppLog.Trim();
                try
                {
                    Process.GetCurrentProcess().PriorityClass = ProcessPriorityClass.AboveNormal;
                }
                catch
                {
                }
                StartVersionCheckThread();
                UpstreamUpdate.CheckInBackground(15);
                var pathChange = AutoStart.CheckAndRepairPath();
                if (pathChange != null)
                {
                    try { Shortcuts.Ensure(); } catch { }
                    ShowPathChangeDialog(pathChange);
                }
                int ownedPid = LaunchOwnership.Get();
                bool working = false;
                bool skipLogged = false;
                var guardStartUtc = DateTime.UtcNow;
                bool autoLaunchDone = false;
                // 若守护启动时 Codex 已在运行（例如启动器被重启），本次不再自动拉起，
                // 避免用户主动关闭 Codex 后又被守护重新打开。
                if (AnyCandidateProcess())
                {
                    autoLaunchDone = true;
                    AppLog.Write("guard.autolaunch.skipped existing-instance");
                }
                CodexInstall install = null;
                DateTime lastDetectUtc = DateTime.MinValue;

                while (true)
                {
                    try
                    {
                        // 1) 读取归属记录：
                        //    - 自己拉起且已确认中文 → 静默
                        //    - 活着但未确认成功（例如上次启动中途被打断）→ 继续往下补救
                        var marked = LaunchOwnership.Get();
                        bool markedAlive = marked != 0 && IsAlive(marked);
                        bool unconfirmedOwned = markedAlive && !LaunchOwnership.IsApplied(marked);
                        if (markedAlive && !unconfirmedOwned)
                        {
                            if (!autoLaunchDone)
                            {
                                autoLaunchDone = true;
                                AppLog.Write("guard.autolaunch.skipped existing-instance");
                            }
                            ownedPid = marked;
                            Thread.Sleep(PollInterval);
                            continue;
                        }
                        if (markedAlive)
                        {
                            ownedPid = marked;
                            AppLog.Write("guard.recover-unconfirmed pid=" + marked);
                        }

                        // 3) 没有 Codex 进程 → 清状态，轻量等待
                        if (!AnyCandidateProcess())
                        {
                            // 3a) 登录后首次：等桌面稳定后，直接以中文界面拉起 Codex。
                            //     比"先起原版再接管"更快，而且登录时不会闪窗口。
                            if (!autoLaunchDone && (DateTime.UtcNow - guardStartUtc) >= AutoLaunchDelay)
                            {
                                autoLaunchDone = true;
                                working = true;
                                try
                                {
                                    if (install == null || !install.IsValid)
                                    {
                                        install = CodexDiscovery.DetectAsync().GetAwaiter().GetResult();
                                        lastDetectUtc = DateTime.UtcNow;
                                    }
                                    if (install != null && install.IsValid)
                                    {
                                        AppLog.Write("guard.autolaunch");
                                        var launched = LocalizationRuntime.LaunchAsync(install, "zh-CN", null)
                                            .GetAwaiter().GetResult();
                                        ownedPid = (int)launched.ProcessId;
                                        AppLog.Write("guard.autolaunched pid=" + ownedPid + " complete=" + launched.Complete);
                                    }
                                }
                                catch (Exception ex)
                                {
                                    AppLog.Write("guard.autolaunch.failed " + ex.Message);
                                }
                                finally
                                {
                                    working = false;
                                }
                                Thread.Sleep(PollInterval);
                                continue;
                            }

                            if (ownedPid != 0) AppLog.Write("guard.codex-exited");
                            ownedPid = 0;
                            LaunchOwnership.Clear();
                            Thread.Sleep(PollInterval);
                            continue;
                        }

                        if (working)
                        {
                            Thread.Sleep(PollInterval);
                            continue;
                        }

                        var now = DateTime.UtcNow;

                        // 4) 检测安装（耗时，首次或超时后才做）
                        if (install == null || (now - lastDetectUtc) > DetectCooldown)
                        {
                            install = CodexDiscovery.DetectAsync().GetAwaiter().GetResult();
                            lastDetectUtc = now;
                        }
                        if (install == null || !install.IsValid)
                        {
                            Thread.Sleep(PollInterval);
                            continue;
                        }

                        var scanRaw = CodexProcessManager.Scan(install);
                        var scan = FilterCurrentSession(scanRaw);
                        if (scan.Verified.Count == 0)
                        {
                            // 有进程但路径对不上（可能是 Codex 新版本换了路径）→ 重新检测
                            if ((now - lastDetectUtc) > DetectCooldown)
                            {
                                install = CodexDiscovery.DetectAsync().GetAwaiter().GetResult();
                                lastDetectUtc = DateTime.UtcNow;
                                if (install != null && install.IsValid)
                                {
                                    scan = FilterCurrentSession(CodexProcessManager.Scan(install));
                                }
                            }
                            if (scan.Verified.Count == 0)
                            {
                                Thread.Sleep(PollInterval);
                                continue;
                            }
                        }

                        // 5) 长会话保护：如果这个实例已经运行超过 30 秒，
                        //    说明可能是你正在使用的会话（例如守护启动晚了），
                        //    绝不强行关闭以免丢失草稿；只记录并等它自己退出。
                        if (!unconfirmedOwned && IsLongRunning(scan, DateTime.UtcNow.AddSeconds(-30)))
                        {
                            if (!skipLogged)
                            {
                                AppLog.Write("guard.skip-long-running count=" + scan.Verified.Count);
                                skipLogged = true;
                            }
                            ownedPid = 0;
                            Thread.Sleep(PollInterval);
                            continue;
                        }
                        skipLogged = false;

                        // 5b) 启动器正在启动 Codex 的瞬间，不要抢
                        if (LaunchOwnership.IsLaunching())
                        {
                            Thread.Sleep(PollInterval);
                            continue;
                        }

                        // 6) 确认是"外来实例" → 静默接管

                        working = true;
                        AppLog.Write("guard.takeover detected=" + scan.Verified.Count);
                        try
                        {
                            CodexProcessManager.ShutdownAsync(
                                install,
                                TimeSpan.FromSeconds(2),
                                TimeSpan.FromSeconds(4),
                                null).GetAwaiter().GetResult();

                            // 给系统一点时间释放单实例锁
                            Thread.Sleep(1200);

                            var report = LocalizationRuntime.LaunchAsync(install, "zh-CN", null)
                                .GetAwaiter().GetResult();
                            ownedPid = (int)report.ProcessId;
                            AppLog.Write("guard.relaunched pid=" + ownedPid + " complete=" + report.Complete);
                        }
                        catch (Exception ex)
                        {
                            AppLog.Write("guard.relaunch.failed " + ex.Message);
                        }
                        finally
                        {
                            working = false;
                        }
                    }
                    catch (Exception ex)
                    {
                        AppLog.Write("guard.loop.failed " + ex.Message);
                    }

                    Thread.Sleep(PollInterval);
                }
            }
        }

        private static bool IsLongRunning(CodexProcessScan scan, DateTime thresholdUtc)
        {
            if (scan.Verified.Count == 0) return false;
            long oldest = long.MaxValue;
            foreach (var info in scan.Verified)
            {
                if (info.StartTimeUtcTicks < oldest) oldest = info.StartTimeUtcTicks;
            }
            if (oldest == long.MaxValue) return false;
            try
            {
                return new DateTime(oldest, DateTimeKind.Utc) < thresholdUtc;
            }
            catch
            {
                return false;
            }
        }
        /// <summary>
        /// 检测 Codex 版本是否变化。变化时弹窗提醒，未变化则静默。
        /// 只在版本确实改变时提示一次（写入新版本号后不再重复）。
        /// </summary>
        private static void CheckCodexVersionChange()
        {
            try
            {
                var install = CodexDiscovery.DetectAsync().GetAwaiter().GetResult();
                if (install == null || !install.IsValid) return;
                var current = (install.Version ?? "").Trim();
                if (current.Length == 0) return;

                var dir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "CodexZhLauncher");
                var file = Path.Combine(dir, "codex-version.txt");
                var last = File.Exists(file) ? File.ReadAllText(file).Trim() : "";

                if (last.Length == 0)
                {
                    Directory.CreateDirectory(dir);
                    File.WriteAllText(file, current);
                    AppLog.Write("version.baseline " + current);
                    return;
                }
                if (String.Equals(last, current, StringComparison.OrdinalIgnoreCase)) return;

                Directory.CreateDirectory(dir);
                File.WriteAllText(file, current);
                AppLog.Write("version.changed " + last + " -> " + current);

                System.Windows.MessageBox.Show(
                    "检测到 Codex 已更新：\n\n" +
                    "  原版本：" + last + "\n" +
                    "  新版本：" + current + "\n\n" +
                    "如果界面没有自动变回中文，请打开「Codex 汉化增强工具」，\n" +
                    "点击界面上的「一键重建」按钮即可修复（自动同步并重启）。\n\n" +
                    "（同一版本只会提示这一次）",
                    "Codex 中文启动器 · 检测到 Codex 更新",
                    System.Windows.MessageBoxButton.OK,
                    System.Windows.MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                AppLog.Write("version.check.failed " + ex.Message);
            }
        }
        /// <summary>
        /// 版本检测放到后台线程，避免登录时阻塞"拉起 Codex"这一步。
        /// </summary>
        private static void StartVersionCheckThread()
        {
            try
            {
                var thread = new Thread(delegate ()
                {
                    CheckCodexVersionChange();
                });
                thread.IsBackground = true;
                thread.Start();
            }
            catch (Exception ex)
            {
                AppLog.Write("version.thread.failed " + ex.Message);
            }
        }
        private static void ShowPathChangeDialog(string change)
        {
            try
            {
                System.Windows.MessageBox.Show(
                    "检测到程序位置已变化：\n\n  " + change + "\n\n" +
                    "已自动更新开机自启项和「Codex 中文版」快捷方式。\n" +
                    "如果之后开机没有自动变中文，请打开一次启动器，重新勾选「开机自启动」。",
                    "Codex 中文启动器 · 检测到程序位置变化",
                    System.Windows.MessageBoxButton.OK,
                    System.Windows.MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                AppLog.Write("path.dialog.failed " + ex.Message);
            }
        }
        private static CodexProcessScan FilterCurrentSession(CodexProcessScan raw)
        {
            var filtered = new CodexProcessScan();
            if (raw == null) return filtered;
            foreach (var info in raw.Verified)
            {
                try
                {
                    using (var process = Process.GetProcessById(info.Id))
                    {
                        if (process.SessionId == CurrentSessionId)
                        {
                            filtered.Verified.Add(info);
                        }
                    }
                }
                catch
                {
                }
            }
            return filtered;
        }

        /// <summary>
        /// 监督模式：作为守护进程的父进程常驻，守护意外退出时自动拉起。
        /// 用户关闭开机自启（注册表项被移除）后，监督自己退出。
        /// </summary>
        public static int Supervise()
        {
            AppLog.Write("supervisor.start");
            while (true)
            {
                try
                {
                    if (!AutoStart.IsEnabled())
                    {
                        AppLog.Write("supervisor.disabled");
                        return 0;
                    }
                    var psi = new ProcessStartInfo
                    {
                        FileName = AutoStart.ExecutablePath,
                        Arguments = "--guard",
                        UseShellExecute = false,
                        CreateNoWindow = true,
                        WindowStyle = ProcessWindowStyle.Hidden
                    };
                    int exitCode = -1;
                    using (var child = Process.Start(psi))
                    {
                        if (child != null)
                        {
                            child.WaitForExit();
                            exitCode = child.ExitCode;
                        }
                    }
                    if (!AutoStart.IsEnabled())
                    {
                        AppLog.Write("supervisor.disabled");
                        return 0;
                    }
                    if (exitCode == 0)
                    {
                        // 已有实例在跑，稍后再试
                        Thread.Sleep(TimeSpan.FromSeconds(60));
                    }
                    else
                    {
                        AppLog.Write("supervisor.restart code=" + exitCode);
                        Thread.Sleep(TimeSpan.FromSeconds(3));
                    }
                }
                catch (Exception ex)
                {
                    AppLog.Write("supervisor.failed " + ex.Message);
                    Thread.Sleep(TimeSpan.FromSeconds(5));
                }
            }
        }
        private static bool AnyCandidateProcess()
        {
            foreach (var name in new[] { "Codex", "ChatGPT" })
            {
                try
                {
                    var processes = Process.GetProcessesByName(name);
                    bool sameSession = false;
                    foreach (var process in processes)
                    {
                        try
                        {
                            if (process.SessionId == CurrentSessionId) sameSession = true;
                        }
                        catch
                        {
                        }
                        process.Dispose();
                    }
                    if (sameSession) return true;
                }
                catch
                {
                }
            }
            return false;
        }

        private static bool IsAlive(int pid)
        {
            if (pid <= 0) return false;
            try
            {
                var process = Process.GetProcessById(pid);
                return !process.HasExited;
            }
            catch
            {
                return false;
            }
        }
    }
}
