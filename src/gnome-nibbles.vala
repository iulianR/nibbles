using Gtk;

public class Nibbles : Gtk.Application
{
    private GLib.Settings settings;

    private bool is_maximized;
    private bool is_tiled;
    private int window_width;
    private int window_height;

    private ApplicationWindow window;
    private HeaderBar headerbar;
    private Stack main_stack;
    private GamesGridFrame frame;

    private NibblesView? view;
    private NibblesGame? game = null;

    private const GLib.ActionEntry action_entries[] =
    {
        {"start-game", start_game_cb},
        {"quit", quit}
    };

    private static const OptionEntry[] option_entries =
    {
        { "version", 'v', 0, OptionArg.NONE, null,
        /* Help string for command line --version flag */
        N_("Show release version"), null},

        { null }
    };

    public Nibbles ()
    {
        Object (application_id: "org.gnome.nibbles", flags: ApplicationFlags.FLAGS_NONE);
        add_main_option_entries (option_entries);
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            /* Not translated so can be easily parsed */
            stderr.printf ("gnome-nibbles %s\n", VERSION);
            return Posix.EXIT_SUCCESS;
        }

        /* Activate */
        return -1;
    }

    protected override void startup ()
    {
        base.startup ();

        add_action_entries (action_entries, this);

        settings = new GLib.Settings ("org.gnome.nibbles");

        set_accels_for_action ("app.quit", {"<Primary>q"});

        var builder = new Builder.from_resource ("/org/gnome/nibbles/ui/gnome-nibbles.ui");
        window = builder.get_object ("nibbles-window") as ApplicationWindow;
        window.size_allocate.connect (size_allocate_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        headerbar = builder.get_object ("headerbar") as HeaderBar;
        main_stack = builder.get_object ("main_stack") as Stack;
        window.set_titlebar (headerbar);

        add_window (window);
    }

    protected override void activate ()
    {
        window.present ();
    }

    protected override void shutdown ()
    {
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
        game.properties.update_settings (settings);

        base.shutdown ();
    }

    /*\
    * * Window events
    \*/

    private void size_allocate_cb (Allocation allocation)
    {
        if (is_maximized || is_tiled)
            return;
        window_width = allocation.width;
        window_height = allocation.height;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        /* We don’t save this state, but track it for saving size allocation */
        if ((event.changed_mask & Gdk.WindowState.TILED) != 0)
            is_tiled = (event.new_window_state & Gdk.WindowState.TILED) != 0;
        return false;
    }

    public bool configure_event_cb (Gdk.EventConfigure event)
    {
        int tile_size, ts_x, ts_y;
        int board_width, board_height;

        /* Compute the new tile size based on the size of the
         * drawing area, rounded down.
         */
        ts_x = event.width / game.width;
        ts_y = event.height / game.height;
        if (ts_x * game.width > event.width)
            ts_x--;
        if (ts_y * game.height > event.height)
            ts_y--;
        tile_size = int.min (ts_x, ts_y);

        if (game.properties.tile_size != tile_size)
        {
            board_width = tile_size * game.width;
            board_height = tile_size * game.height;

            view.stage.set_size (board_width, board_height);
            view.surface.set_size (board_width, board_height);

            game.properties.tile_size = tile_size;
        }

        return false;
    }

    private void start_game_cb ()
    {
        start_game ();
    }

    private void show_new_game_screen ()
    {
        main_stack.set_visible_child_name ("start_box");
    }

    private void show_game_view ()
    {
        main_stack.set_visible_child_name ("frame");
    }

    private void start_game ()
    {
        if (game != null)
        {
            SignalHandler.disconnect_matched (game, SignalMatchType.DATA, 0, 0, null, null, this);
        }

        game = new NibblesGame ();
        game.properties.update_properties (settings);

        view = new NibblesView (game);
        view.configure_event.connect (configure_event_cb);

        frame = new GamesGridFrame (game.width, game.height);
        main_stack.add_named (frame, "frame");

        frame.add (view);
        frame.show_all ();

        game.current_level = game.properties.start_level;
        view.new_level (game.current_level);
        show_game_view ();
    }

    public static int main (string[] args)
    {
        var context = new OptionContext ("");

        context.add_group (Gtk.get_option_group (false));
        context.add_group (Clutter.get_option_group_without_init ());

        try
        {
            context.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        Environment.set_application_name (_("Nibbles"));

        try
        {
            GtkClutter.init_with_args (ref args, "", new OptionEntry[0], null);
        }
        catch (Error e)
        {
            var dialog = new Gtk.MessageDialog (null,
                                                DialogFlags.MODAL,
                                                MessageType.ERROR,
                                                ButtonsType.NONE,
                                                "Unable to initialize Clutter:\n%s", e.message);
            dialog.set_title (Environment.get_application_name ());
            dialog.run ();
            dialog.destroy ();
            return Posix.EXIT_FAILURE;
        }

        return new Nibbles ().run (args);
    }
}