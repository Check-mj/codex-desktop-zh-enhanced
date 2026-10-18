using System;
using System.IO;
using System.Threading;

namespace CodexZhLauncher
{
    /// <summary>
    /// 上游启动器（shibaweidu/codex-desktop-zh）版本检查。
    /// 如果上游发布了比"当前构建所基于的版本"更新的版本，弹窗提醒重新构建
    /// （重新构建.cmd -Update 会自动套用我们的全部改动并重新签名）。
    /// 同一上游版本只提示一次。
    /// </summary>
    internal static class UpstreamUpdate
    {
        private static readonly string DataDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CodexZhLauncher");

        private static readonly string NotifiedFile = Path.Combine(DataDirectory, "upstream-notified.txt");

        /// <summary>后台线程延迟检查，避免影响登录/启动速度。</summary>
        public static void CheckInBackground(int delaySeconds)
        {
            try
            {
                var thread = new Thread(delegate ()
                {
                    try
                    {
                        Thread.Sleep(TimeSpan.FromSeconds(delaySeconds));
                        CheckAndNotify(true);
                    }
                    catch (Exception ex)
                    {
                        AppLog.Write("upstream.check.failed " + ex.Message);
                    }
                });
                thread.IsBackground = true;
                thread.Start();
            }
            catch (Exception ex)
            {
                AppLog.Write("upstream.thread.failed " + ex.Message);
            }
        }

        /// <summary>
        /// 检查上游版本。showDialog 为 true 时在发现新版本且未提示过时弹窗。
        /// 返回 "none" / "update" / "notified" / "error"。
        /// </summary>
        public static string CheckAndNotify(bool showDialog)
        {
            UpdateCheckResult result;
            try
            {
                result = UpdateChecker.CheckAsync(AppInfo.UpstreamBaseVersion).GetAwaiter().GetResult();
            }
            catch (Exception ex)
            {
                AppLog.Write("upstream.check.failed " + ex.Message);
                return "error";
            }

            if (!result.UpdateAvailable)
            {
                AppLog.Write("upstream.latest v" + result.LatestVersion + " base=v" + AppInfo.UpstreamBaseVersion);
                return "none";
            }

            var last = "";
            try
            {
                if (File.Exists(NotifiedFile)) last = File.ReadAllText(NotifiedFile).Trim();
            }
            catch
            {
            }

            if (String.Equals(last, result.LatestVersion, StringComparison.OrdinalIgnoreCase))
            {
                AppLog.Write("upstream.notified.already v" + result.LatestVersion);
                return "notified";
            }

            try
            {
                Directory.CreateDirectory(DataDirectory);
                File.WriteAllText(NotifiedFile, result.LatestVersion);
            }
            catch
            {
            }
            AppLog.Write("upstream.update.available v" + result.LatestVersion + " base=v" + AppInfo.UpstreamBaseVersion);

            if (showDialog)
            {
                ShowUpdateDialog(result.LatestVersion);
            }
            return "update";
        }

        private static void ShowUpdateDialog(string latestVersion)
        {
            try
            {
                System.Windows.MessageBox.Show(
                    "上游启动器发布了新版本：v" + latestVersion + "\n\n" +
                    "当前构建基于：v" + AppInfo.UpstreamBaseVersion + "\n\n" +
                    "请打开「Codex 汉化增强工具」，点击界面上的「一键重建」按钮，\n" +
                    "即可自动同步上游、套用本地改动、重新签名并重启。\n\n" +
                    "同一上游版本只会提示这一次。",
                    "Codex 中文启动器 · 上游有更新",
                    System.Windows.MessageBoxButton.OK,
                    System.Windows.MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                AppLog.Write("upstream.dialog.failed " + ex.Message);
            }
        }
    }
}
