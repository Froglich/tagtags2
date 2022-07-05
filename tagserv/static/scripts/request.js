var statusCodes = {
	//Success codes
	200: 'OK',
	201: 'Created',
	202: 'Accepted',
	203: 'Non-Authoritative Information',
	204: 'No Content',
	205: 'Reset Content',
	206: 'Partial Content',
	//Redirect codes
	300: 'Multiple Choises',
	301: 'Moved Permanently',
	302: 'Found',
	303: 'See Other',
	304: 'Not Modified',
	305: 'Use Proxy',
	307: 'Temporary Redirect',
	308: 'Permanent Redirect',
	//Client errors
	400: 'Bad Request',
	401: 'Unauthorized',
	403: 'Forbidden',
	404: 'Not Found',
	405: 'Method Not Allowed',
	406: 'Not Acceptable',
	408: 'Request Timeout',
	409: 'Conflict',
	410: 'Gone',
    411: 'Length Required',
    415: 'Unsupported Media Type',
	417: 'Expectation Failed',
	418: 'I\'m a teapot',
	426: 'Update Required',
	429: 'Too Many Requests',
	//Server errors
	500: 'Internal Server Error',
	501: 'Not Implemented',
	502: 'Bad Gateway',
	503: 'Service Unavailable',
	504: 'Gateway Timeout',
	505: 'HTTP Version Not Supported'
};

function formatStatusCode(status) {
    return `[ERROR ${status}]: ${statusCodes[status]}`;
}

function urlEncodeObject(obj) {
    let params = [];
    let postdata = '';

    if(obj) {
        if(typeof globalThemeID !== 'undefined') {
            obj['theme'] = globalThemeID;
        }

        for(let key in obj) {
            params.push(encodeURIComponent(key) + '=' + encodeURIComponent(obj[key]))
        }

        postdata = params.join('&');
    }

    return postdata;
}

/**
 * Build an ascynchronous http request
 * @param {string} requestUrl - URL to call.
 */
function Request(requestUrl) {
    let url = requestUrl;
    let successCallback = null;
    let successCallbackJSON = null;
    let finallyCallback = null;
    let errorCallback = null;
    let xhr = new XMLHttpRequest();
    let active = false;
    let loaderElement = null;
	let overlayLoaderTarget = null;
    let loader = null;

    let contentType = 'application/x-www-form-urlencoded';

    let error = function(status, msg) {
        if(errorCallback != null) {
            errorCallback(status, msg);
        }
    };

    let call = function(method, data) {
        if(loaderElement !== null) {
            loader = buildLoader();
            loaderElement.appendChild(loader);
        } else if(overlayLoaderTarget !== null) {
			let parent = overlayLoaderTarget.parentElement;
			let height = overlayLoaderTarget.offsetHeight;
			let width = overlayLoaderTarget.offsetWidth;
			let top = overlayLoaderTarget.offsetTop;
			let left = overlayLoaderTarget.offsetLeft;

            loader = newDOMObject('div', {
                className: 'embedded_loader',
                style: {
                    height: height + 'px',
                    width: width + 'px',
                    top: top + 'px',
                    left: left + 'px'
                }
            });
            parent.appendChild(loader);
		}

        xhr.addEventListener('load', function() {
            if(xhr.status == 200) {
                if(successCallback != null) {
                    successCallback(xhr.responseText);
                }

                if(successCallbackJSON != null) {
                    try {
                        j = JSON.parse(xhr.responseText);
                        successCallbackJSON(j);
                    } catch(e) {
                        error(200, 'Serverns svar var felformaterat: ' + e);
                    }
                }
            } else if (xhr.status != 200) {
                error(xhr.status, xhr.responseText);
            }
        });

        xhr.addEventListener('loadend', function() {
            active = false;
            if(finallyCallback != null) {
                finallyCallback();
            }

            if(loader !== null) {
                //Ifs in case the loader was removed by one of the callback functions.
                if(loaderElement == loader.parentNode) loaderElement.removeChild(loader);
				if(overlayLoaderTarget && overlayLoaderTarget.parentElement) overlayLoaderTarget.parentElement.removeChild(loader);
            }
        });

        xhr.addEventListener('error', function(e) {
            error(xhr.status, e.type);
        });

        xhr.open(method, url, true);

        if(contentType != null) {
            xhr.setRequestHeader('Content-type', contentType);
        }

        xhr.send(data);
        active = true;
    };

    let urlEncodeData = function(data) {
        if(data) {
            url = url + '?' + urlEncodeObject(data);
        }
    }

    /**
     * Define an element to append an animated spinner to while the request is active
     * @param {string} selector
     */
    this.setLoaderParent = function(node) {
        if(node instanceof HTMLElement) loaderElement = node;
        else if(typeof node === 'string') loaderElement = document.querySelector(node);
        else console.log('Not sure how to handle loader parent of type ' + (typeof node));

        return this;
    }

	/**
	 * Define an element to display an animated spinner on top of while the request is active
	 * @param {string} selector
	 */
	this.setOverlayLoaderTarget = function(node) {
		if(node instanceof HTMLElement) overlayLoaderTarget = node;
        else if(typeof node === 'string') overlayLoaderTarget = document.querySelector(node);
        else console.log('Not sure how to handle overlay loader target of type ' + (typeof node));

        return this;
	}

    /**
     * Provide a function to call when the request completes successfully
     * @param {function} callback
     */
    this.onSuccess = function(callback) {
        successCallback = callback;
        return this;
    };

    /**
     * Provide a function to call when the request completes successfully
     * @param {function} callback
     */
    this.onSuccessJSON = function(callback) {
        successCallbackJSON = callback;
        return this;
    };

    /**
     * Provide a function to call when the request does not complete successfully
     * @param {function} callback
     */
    this.onError = function(callback) {
        errorCallback = callback;
        return this;
    }

    /**
     * Provide a function to call when the request completes regardless if it is successful or not
     * @param {function} callback
     */
    this.onComplete = function(callback) {
        finallyCallback = callback;
        return this;
    };

    /**
     * Set the content type of the request
     * @param {string} type
     */
    this.setContentType = function(type) {
        contentType = type;
        return this;
    };

    /**
     * Perform a POST request with all previously defined parameters
     * @param {object} data
     */
    this.POST = function(data) {
        if(data instanceof FormData) {
            call('post', data);
        } else {
            call('post', urlEncodeObject(data));
        }
        return this;
    };

    /**
     * Perform a GET request with all previously defined parameters
     * @param {object} data
     */
    this.GET = function(data) {
        urlEncodeData(data);
        call('get', null);
        return this;
    };

    /**
     * Perform a DELETE request with all previously defined parameters
     * @param {object} data
     */
    this.DELETE = function(data) {
        urlEncodeData(data);
        call('delete', null);
        return this;
    };

    /**
     * Perform a PUT request with all previously defined parameters
     * @param {object} data
     */
    this.PUT = function(data) {
        if(data instanceof FormData) {
            call('put', data);
        } else {
            call('put', urlEncodeObject(data));
        }
        return this;
    }

    /**
     * Abort an ongoing request
     */
    this.abort = function() {
        if(active == true) {
            xhr.abort();

            if(mustfinish === true) {
                updatePrioLoading(-1);
            } else {
                updateLoading(-1);
            }
        }
    };
}
