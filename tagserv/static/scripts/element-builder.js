function massSetElementStyle(element, styles) {
    for(let key in styles) {
        element.style[key] = styles[key];
    }
}

function massAppendChild(element, children) {
    for(let x = 0; x < children.length; x++) {
        let child = children[x];

        if(typeof child.setAttribute === 'function') {
            element.appendChild(child);
        } else if(typeof child === 'string' || child instanceof String) {
            element.insertAdjacentHTML('beforeend', child);
        } else {
            element.appendChild(buildElement(child));
        }
    }
}

function massAddEventListener(element, eventListeners) {
    for(let x = 0; x < eventListeners.length; x++) {
        let eventListener = eventListeners[x];

        if(eventListener.event.toLowerCase() === 'interact') {
            addUserInteractListener(element, eventListener.listener)
        } else {
            element.addEventListener(eventListener.event, eventListener.listener);
        }
    }
}

function buildElement(params) {
    if(!('tag' in params)) {
        throw 'Tag not specified.';
    }

    let element = document.createElement(params.tag);
    delete params.tag;

    for(let key in params) {
        let val = params[key];

        switch(key.toLowerCase()) {
            case 'innerhtml':
                element.innerHTML = val;
                break;
            case 'children':
                massAppendChild(element, val);
                break;
            case 'style':
                massSetElementStyle(element, val);
                break;
            case 'eventlisteners':
                massAddEventListener(element, val);
                break;
            case 'checked':
                element.checked = val;
                break;
            default:
                element.setAttribute(key, val);
        }
    }

    return element;
}

function buildLoader() {
    return buildElement({tag: 'div', class: 'large-loader'});
}
