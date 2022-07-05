/**
 * Generate a default Leaflet map
 * @author Kim Lindgren
 * @copyright SLU © 2021
 */

let buildDefaultMap = function(container) {
    let map = new L.Map(container, {
        continuousWorld: true,
        zoomControl: false
    });

    L.control.scale({position: 'bottomright'}).addTo(map);
    L.control.zoom({position: 'bottomright'}).addTo(map);

    map.setView([62.629, 17.931], 5);

    L.tileLayer('https://b.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 17,
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        continuousWorld: true
    }).addTo(map);

    return map;
};

let mapFitLayerBounds = function(map, layer) {
    setTimeout(function() {
        b1 = layer.getBounds();
        b2 = map.getBounds();

        if(getBoundsHeight(b1) > getBoundsHeight(b2)) {
            map.setView([b1.getCenter().lat, b1.getCenter().lng], map.getZoom());
        } else {
            map.fitBounds(b1);
        }

    }, 300);
};

let getBoundsHeight = function(bounds) {
    return (bounds._northEast.lat - bounds._southWest.lat);
};
