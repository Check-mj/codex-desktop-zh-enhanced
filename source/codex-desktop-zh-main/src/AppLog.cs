using System;
using System.IO;
using System.Text;

namespace CodexZhLauncher
{
    internal static class AppLog
    {
        private static readonly object Sync = new object();
        public static readonly string DirectoryPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CodexZhLauncher",
            "logs");
        public static readonly string FilePath = Path.Combine(DirectoryPath, "launcher.log");

        /// <summary>
        /// 日志清理：超过 maxBytes 就把旧日志改名成 .old（只保留一份），重新开始写。
        /// 默认 1 MB，对守护这种长期运行的场景足够。
        /// </summary>
        public static void Trim(long maxBytes = 1048576)
        {
            try
            {
                lock (Sync)
                {
                    var info = new FileInfo(FilePath);
                    if (!info.Exists || info.Length <= maxBytes) return;
                    var backup = FilePath + ".old";
                    if (File.Exists(backup)) File.Delete(backup);
                    File.Move(FilePath, backup);
                }
            }
            catch
            {
            }
        }

        private static readonly string UserProfilePath =
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        /// <summary>写入日志前对用户目录做脱敏，避免把本机 Windows 用户名写进日志。</summary>
        private static string Scrub(string message)
        {
            if (String.IsNullOrEmpty(message)) return message;
            var result = message;
            try
            {
                var home = UserProfilePath;
                if (!String.IsNullOrEmpty(home))
                {
                    result = result.Replace(home, "%USERPROFILE%");
                }
            }
            catch
            {
            }
            try
            {
                result = System.Text.RegularExpressions.Regex.Replace(
                    result,
                    @"[A-Za-z]:\\Users\\[^\\\s""]+",
                    @"%USERPROFILE%",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);
            }
            catch
            {
            }
            return result;
        }
        public static void Write(string message)
        {
            try
            {
                lock (Sync)
                {
                    Directory.CreateDirectory(DirectoryPath);
                    File.AppendAllText(
                        FilePath,
                        DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff") + "  " + Scrub(message) + Environment.NewLine,
                        new UTF8Encoding(false));
                }
            }
            catch
            {
            }
        }
    }
}

