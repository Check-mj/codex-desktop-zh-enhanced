using System;
using System.IO;

namespace CodexZhLauncher
{
    /// <summary>
    /// 记录"当前由启动器拉起的 Codex 进程 PID"，
    /// 供守护模式判断某个实例是不是自己启动的，避免重复重启。
    /// </summary>
    internal static class LaunchOwnership
    {
        private static readonly string DirectoryPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "CodexZhLauncher");
        private static readonly string FilePath = Path.Combine(DirectoryPath, "owned-pid.txt");

        public static void Mark(int pid)
        {
            try
            {
                Directory.CreateDirectory(DirectoryPath);
                File.WriteAllText(FilePath, pid.ToString());
            }
            catch (Exception ex)
            {
                AppLog.Write("ownership.mark.failed " + ex.Message);
            }
        }

        public static int Get()
        {
            try
            {
                if (!File.Exists(FilePath)) return 0;
                int pid;
                return Int32.TryParse(File.ReadAllText(FilePath).Trim(), out pid) ? pid : 0;
            }
            catch
            {
                return 0;
            }
        }

        private static readonly string LaunchingFile = Path.Combine(DirectoryPath, "launching.flag");

        /// <summary>启动前打标记，防止守护在启动瞬间把它当成"外来实例"抢走。</summary>
        public static void BeginLaunch()
        {
            try
            {
                Directory.CreateDirectory(DirectoryPath);
                File.WriteAllText(LaunchingFile, DateTime.UtcNow.ToString("o"));
            }
            catch
            {
            }
        }

        public static void EndLaunch()
        {
            try
            {
                if (File.Exists(LaunchingFile)) File.Delete(LaunchingFile);
            }
            catch
            {
            }
        }

        public static bool IsLaunching()
        {
            try
            {
                if (!File.Exists(LaunchingFile)) return false;
                DateTime started;
                if (!DateTime.TryParse(File.ReadAllText(LaunchingFile).Trim(), null,
                        System.Globalization.DateTimeStyles.RoundtripKind, out started)) return false;
                return (DateTime.UtcNow - started.ToUniversalTime()).TotalSeconds < 90;
            }
            catch
            {
                return false;
            }
        }

        private static readonly string AppliedFile = Path.Combine(DirectoryPath, "owned-applied.txt");

        /// <summary>注入成功、界面确认中文后写入，表示这个实例是"已完成"的。</summary>
        public static void MarkApplied(int pid)
        {
            try
            {
                Directory.CreateDirectory(DirectoryPath);
                File.WriteAllText(AppliedFile, pid.ToString());
            }
            catch
            {
            }
        }

        /// <summary>该 PID 是否已被确认汉化成功。</summary>
        public static bool IsApplied(int pid)
        {
            try
            {
                if (pid <= 0 || !File.Exists(AppliedFile)) return false;
                int applied;
                return Int32.TryParse(File.ReadAllText(AppliedFile).Trim(), out applied) && applied == pid;
            }
            catch
            {
                return false;
            }
        }

        public static void Clear()
        {
            try
            {
                if (File.Exists(FilePath)) File.Delete(FilePath);
                if (File.Exists(AppliedFile)) File.Delete(AppliedFile);
            }
            catch
            {
            }
        }
    }
}
