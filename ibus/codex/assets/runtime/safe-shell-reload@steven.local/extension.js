const {Gio, GLib, Meta} = imports.gi;

const OBJECT_PATH = '/com/steven/SafeShellReload';
const INTERFACE_XML = `
<node>
  <interface name="com.steven.SafeShellReload">
    <method name="Reload"/>
  </interface>
</node>`;

class SafeShellReload {
    enable() {
        this._dbusObject = Gio.DBusExportedObject.wrapJSObject(INTERFACE_XML, this);
        this._dbusObject.export(Gio.DBus.session, OBJECT_PATH);
    }

    Reload() {
        GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            Meta.restart('正在安全重载桌面…');
            return GLib.SOURCE_REMOVE;
        });
    }

    disable() {
        if (this._dbusObject) {
            this._dbusObject.unexport();
            this._dbusObject = null;
        }
    }
}

function init() {
    return new SafeShellReload();
}
