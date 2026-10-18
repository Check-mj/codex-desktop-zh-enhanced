using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace CodexZhLauncher
{
    /// <summary>
    /// 一键重建后的自更新：等当前启动器进程全部退出 → 用新构建替换 exe
    /// → 重新拉起监督进程和界面。因为正在运行的 exe 无法被覆盖，必须借道 cmd。
    /// </summary>
    internal static class SelfUpdate
    {
        public static bool RestartWithBuiltExe(string builtExe)
        {
            try
            {
                if (String.IsNullOrEmpty(builtExe) || !File.Exists(builtExe)) return false;
                var target = AutoStart.ExecutablePath;
                if (String.IsNullOrEmpty(target) || !File.Exists(target)) return false;

                var script = Path.Combine(Path.GetTempPath(), "codex-zh-selfupdate.cmd");
                var content =
                    "@echo off\r\n" +
                    "timeout /t 2 /nobreak >nul\r\n" +
                    "taskkill /f /im \"" + Path.GetFileName(target) + "\" >nul 2>&1\r\n" +
                    "timeout /t 3 /nobreak >nul\r\n" +
                    "copy /y \"" + builtExe + "\" \"" + target + "\" >nul\r\n" +
                    "start \"\" \"" + target + "\" --supervise\r\n" +
                    "start \"\" \"" + target + "\"\r\n" +
                    "del \"%~f0\"\r\n";
                File.WriteAllText(script, content, Encoding.Default);

                var psi = new ProcessStartInfo
                {
                    FileName = "cmd.exe",
                    Arguments = "/c \"" + script + "\"",
                    UseShellExecute = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                Process.Start(psi);
                AppLog.Write("selfupdate.scheduled target=" + target + " built=" + builtExe);
                return true;
            }
            catch (Exception ex)
            {
                AppLog.Write("selfupdate.failed " + ex.Message);
                return false;
            }
        }
    }
}
