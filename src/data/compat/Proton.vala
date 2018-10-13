/*
This file is part of GameHub.
Copyright (C) 2018 Anatoliy Kashkin

GameHub is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GameHub is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GameHub.  If not, see <https://www.gnu.org/licenses/>.
*/

using GameHub.Utils;

using GameHub.Data.Sources.Steam;

namespace GameHub.Data.Compat
{
	public class Proton: Wine
	{
		public const string[] APPIDS = {"961940", "930400", "858280"}; // 3.16, 3.7 Beta, 3.7

		public string appid { get; construct; }

		public Proton(string appid)
		{
			Object(appid: appid, binary: "", arch: "");
		}

		construct
		{
			id = @"proton_$(appid)";
			name = "Proton";
			icon = "source-steam-symbolic";
			installed = false;

			options = {
				new CompatTool.Option("PROTON_NO_ESYNC", _("Disable esync"), false),
				new CompatTool.Option("PROTON_NO_D3D11", _("Disable DirectX 11 compatibility layer"), false),
				new CompatTool.Option("PROTON_USE_WINED3D11", _("Use WineD3D11 as DirectX 11 compatibility layer"), false),
				new CompatTool.Option("DXVK_HUD", _("Show DXVK info overlay"), true)
			};

			File? proton_dir = null;
			if(Steam.find_app_install_dir(appid, out proton_dir))
			{
				if(proton_dir != null)
				{
					name = proton_dir.get_basename();
					executable = proton_dir.get_child("proton");
					installed = executable.query_exists();
					wine_binary = proton_dir.get_child("dist/bin/wine");
				}
			}

			if(installed)
			{
				actions = {
					new CompatTool.Action("prefix", _("Open prefix directory"), game => {
						Utils.open_uri(get_wineprefix(game).get_uri());
					}),
					new CompatTool.Action("winecfg", _("Run winecfg"), game => {
						wineutil.begin(null, game, "winecfg");
					}),
					new CompatTool.Action("winetricks", _("Run winetricks"), game => {
						winetricks.begin(null, game);
					}),
					new CompatTool.Action("regedit", _("Run regedit"), game => {
						wineutil.begin(null, game, "regedit");
					})
				};
			}
		}

		protected override async void exec(Game game, File file, File dir, string[]? args=null, bool parse_opts=true)
		{
			string[] cmd = { executable.get_path(), "run", file.get_path() };
			if(args != null)
			{
				foreach(var arg in args) cmd += arg;
			}
			yield Utils.run_thread(cmd, dir.get_path(), prepare_env(game, parse_opts));
		}

		protected override File get_wineprefix(Game game)
		{
			return FSUtils.mkdir(game.install_dir.get_path(), @"$(COMPAT_DATA_DIR)/proton_$(name)/pfx");
		}

		protected override string[] prepare_env(Game game, bool parse_opts=true)
		{
			var env = Environ.get();

			var compatdata = FSUtils.mkdir(game.install_dir.get_path(), @"$(COMPAT_DATA_DIR)/proton_$(name)");
			if(compatdata != null && compatdata.query_exists())
			{
				env = Environ.set_variable(env, "STEAM_COMPAT_CLIENT_INSTALL_PATH", FSUtils.Paths.Steam.Home);
				env = Environ.set_variable(env, "STEAM_COMPAT_DATA_PATH", compatdata.get_path());
				env = Environ.set_variable(env, "PROTON_LOG", "1");
				env = Environ.set_variable(env, "PROTON_DUMP_DEBUG_COMMANDS", "1");
			}

			if(parse_opts)
			{
				foreach(var opt in options)
				{
					if(opt.enabled)
					{
						env = Environ.set_variable(env, opt.name, "1");
					}
				}
			}

			return env;
		}
	}
}
