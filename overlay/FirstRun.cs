using System;
using System.IO;

namespace CodexZhLauncher
{
    /// <summary>
    /// 首次启动标记：只在第一次打开工具时弹出使用说明，之后不再打扰。
    /// </summary>
    internal static class FirstRun
    {
        private static readonly string DirectoryPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CodexZhLauncher");

        private static readonly string MarkerPath = Path.Combine(DirectoryPath, "first-run.done");

        public static bool NeedShow()
        {
            try
            {
                return !File.Exists(MarkerPath);
            }
            catch
            {
                return false;
            }
        }

        public static void MarkShown()
        {
            try
            {
                Directory.CreateDirectory(DirectoryPath);
                File.WriteAllText(MarkerPath, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
                AppLog.Write("firstrun.marked");
            }
            catch (Exception ex)
            {
                AppLog.Write("firstrun.mark.failed " + ex.Message);
            }
        }
    }
}
