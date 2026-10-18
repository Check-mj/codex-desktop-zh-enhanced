using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using Microsoft.Win32;

namespace CodexZhLauncher
{
    /// <summary>
    /// 开机自启动：写入 HKCU\...\Run，登录 Windows 时自动以中文界面拉起 Codex。
    /// 只改当前用户的注册表，不需要管理员权限。
    /// </summary>
    internal static class AutoStart
    {
        private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
        private const string ValueName = "CodexZhLauncherZh";

        public static string ExecutablePath
        {
            get
            {
                try
                {
                    var assembly = Assembly.GetEntryAssembly();
                    if (assembly != null && !String.IsNullOrEmpty(assembly.Location))
                    {
                        return assembly.Location;
                    }
                }
                catch
                {
                }
                return Process.GetCurrentProcess().MainModule.FileName;
            }
        }

        public static string CommandLine
        {
            get { return "\"" + ExecutablePath + "\" --supervise"; }
        }

        public static bool IsEnabled()
        {
            try
            {
                using (var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false))
                {
                    if (key == null) return false;
                    var value = key.GetValue(ValueName) as string;
                    return !String.IsNullOrEmpty(value);
                }
            }
            catch (Exception ex)
            {
                AppLog.Write("autostart.read.failed " + ex.Message);
                return false;
            }
        }

        public static void SetEnabled(bool enabled)
        {
            using (var key = Registry.CurrentUser.CreateSubKey(RunKeyPath))
            {
                if (key == null) throw new InvalidOperationException("无法打开注册表 Run 键。");
                if (enabled)
                {
                    key.SetValue(ValueName, CommandLine, RegistryValueKind.String);
                    AppLog.Write("autostart.enabled " + CommandLine);
                }
                else
                {
                    key.DeleteValue(ValueName, false);
                    AppLog.Write("autostart.disabled");
                }
            }
        }

        private static readonly string DataDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CodexZhLauncher");

        private static readonly string InstallPathFile = Path.Combine(DataDirectory, "install-path.txt");

        /// <summary>
        /// 检测程序是否被移动到其他位置。
        /// 发生变化时：自动把开机自启项改写为新路径，并返回 "旧路径 -> 新路径"；没变化返回 null。
        /// </summary>
        public static string CheckAndRepairPath()
        {
            try
            {
                var exe = ExecutablePath;
                if (String.IsNullOrEmpty(exe)) return null;
                var current = Path.GetDirectoryName(exe) ?? "";
                if (current.Length == 0) return null;

                string last = "";
                try
                {
                    if (File.Exists(InstallPathFile)) last = File.ReadAllText(InstallPathFile).Trim();
                }
                catch
                {
                }

                if (last.Length == 0)
                {
                    Directory.CreateDirectory(DataDirectory);
                    File.WriteAllText(InstallPathFile, current);
                    AppLog.Write("path.baseline " + current);
                    return null;
                }

                if (String.Equals(last, current, StringComparison.OrdinalIgnoreCase)) return null;

                Directory.CreateDirectory(DataDirectory);
                File.WriteAllText(InstallPathFile, current);
                AppLog.Write("path.changed " + last + " -> " + current);

                // 自动修复开机自启项（如果本来就开启着）
                bool wasEnabled = IsEnabled();
                if (wasEnabled)
                {
                    try
                    {
                        SetEnabled(true);
                        AppLog.Write("path.autostart.repaired");
                    }
                    catch (Exception ex)
                    {
                        AppLog.Write("path.autostart.repair.failed " + ex.Message);
                    }
                }
                return last + " -> " + current;
            }
            catch (Exception ex)
            {
                AppLog.Write("path.check.failed " + ex.Message);
                return null;
            }
        }
    }
}
