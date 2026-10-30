import QtQuick
import Ros2

QtObject {
    property var __cache: []
    property bool cache: true
    property string objectServiceTopic

    function lookup(id, cacheOnly) {
        if (cache) {
            for (var i in __cache) {
                if (__cache[i].object_id != id)
                    continue;
                return __cache[i];
            }
        }
        if (cacheOnly)
            return undefined;
        var result = Service.call(objectServiceTopic, "worldmodel_server_msgs/GetObjectById", {
                "object_id": id
            });
        if (!result) {
            Ros2.warn("Unable to obtain object with id: " + id);
            return;
        }
        if (cache)
            __cache.push(result.object);
        return result.object;
    }
    function lookupAsync(id, resultCallback) {
        if (cache) {
            for (var i in __cache) {
                if (__cache[i].object_id != id)
                    continue;
                resultCallback(__cache[i]);
                return;
            }
        }
        Service.callAsync(objectServiceTopic, "worldmodel_server_msgs/GetObjectById", {
                "object_id": id
            }, function (result) {
                if (!result) {
                    Ros2.warn("Unable to obtain object with id: " + id);
                    return;
                }
                resultCallback(result.object);
                if (cache)
                    __cache.push(result.object);
            });
    }
}
