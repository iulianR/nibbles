public class Properties : Object
{
    public int tile_size;
    public int start_level;

    public Properties ()
    {

    }

    public void update_settings (GLib.Settings settings)
    {
        settings.set_int ("tile-size", tile_size);
        settings.set_int ("start-level", start_level);
    }

    public void update_properties (GLib.Settings settings)
    {
        tile_size = settings.get_int ("tile-size");
        start_level = settings.get_int ("start-level");
    }
}