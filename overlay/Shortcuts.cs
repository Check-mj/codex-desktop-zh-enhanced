using System;
using System.IO;
using System.Reflection;

namespace CodexZhLauncher
{
    /// <summary>
    /// 首次启动时自动创建“Codex 中文版”快捷方式（桌面 + 开始菜单）。
    /// 这是与“开机自启守护”并行的第二条路：直接点快捷方式即中文启动，没有接管延迟。
    /// 已存在且指向正确时不会重复创建。
    /// </summary>
    internal static class Shortcuts
    {
        private const string ShortcutName = "Codex 中文版.lnk";

        public static void Ensure()
        {
            try
            {
                var exe = AutoStart.ExecutablePath;
                if (String.IsNullOrEmpty(exe) || !File.Exists(exe)) return;

                var desktop = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
                var programs = Environment.GetFolderPath(Environment.SpecialFolder.Programs);

                bool created = false;
                created |= CreateOne(Path.Combine(desktop, ShortcutName), exe);
                if (!String.IsNullOrEmpty(programs))
                {
                    created |= CreateOne(Path.Combine(programs, ShortcutName), exe);
                }
                if (created)
                {
                    AppLog.Write("shortcut.created " + ShortcutName);
                }
            }
            catch (Exception ex)
            {
                AppLog.Write("shortcut.failed " + ex.Message);
            }
        }

        private static bool CreateOne(string path, string exe)
        {
            var shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null)
            {
                return false;
            }
            var shell = Activator.CreateInstance(shellType);

            if (File.Exists(path))
            {
                // 已存在：检查指向是否正确，正确就不动；被移动/改坏则重写
                try
                {
                    var existing = shellType.InvokeMember(
                        "CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
                    var existingType = existing.GetType();
                    var target = existingType.InvokeMember(
                        "TargetPath", BindingFlags.GetProperty, null, existing, null) as string;
                    var arguments = existingType.InvokeMember(
                        "Arguments", BindingFlags.GetProperty, null, existing, null) as string;
                    if (String.Equals(target, exe, StringComparison.OrdinalIgnoreCase) &&
                        String.Equals(arguments, "--launch-zh", StringComparison.OrdinalIgnoreCase))
                    {
                        return false;
                    }
                }
                catch
                {
                }
            }

            var shortcut = shellType.InvokeMember(
                "CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
            var shortcutType = shortcut.GetType();
            shortcutType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { exe });
            shortcutType.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { "--launch-zh" });
            shortcutType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut,
                new object[] { Path.GetDirectoryName(exe) });
            shortcutType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut,
                new object[] { exe + ",0" });
            shortcutType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut,
                new object[] { "以中文界面启动 Codex Desktop（无需等待后台接管）" });
            shortcutType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
            return true;
        }
    }
}
