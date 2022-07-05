let FancyDialog = function(title) {
    let titleE = document.createElement('h1');
    titleE.innerHTML = title;
    this.title = titleE;

    let content = document.createElement('div');
    content.setAttribute('class', '-fancy-dialog-content');
    this.content = content;

    let buttons = document.createElement('div');
    buttons.setAttribute('class', '-fancy-dialog-buttons');
    this.buttons = buttons;

    let dialog = document.createElement('div');
    dialog.setAttribute('class', '-fancy-dialog');
    dialog.appendChild(titleE);
    dialog.appendChild(content);
    dialog.appendChild(buttons);
    this.dialog = dialog;

    let closeButton = document.createElement('input');
    closeButton.setAttribute('type', 'button');
    closeButton.setAttribute('value', 'Close');
    this.closeButton = closeButton;

    let closeOutside = document.createElement('div');
    closeOutside.setAttribute('class', '-fancy-dialog-intuitive-interaction');

    let shader = document.createElement('fancy-dialog-shader');
    shader.appendChild(closeOutside);
    shader.appendChild(dialog);

    this.show = function() {
        if(!closeButton.parentElement) buttons.appendChild(closeButton);

        dialog.setAttribute('fancy-dialog-slide', 'in');
        document.body.appendChild(shader);
        dialog.focus();
    }

    this.hide = function() {
        shader.style.opacity = 0;
        shader.style.pointerEvents = 'none';
        dialog.setAttribute('fancy-dialog-slide', 'out');

        setTimeout(function() {
            document.body.removeChild(shader);
            shader.style.opacity = 1;
            shader.style.pointerEvents = 'auto';
        }, 200);
    }

    closeButton.addEventListener('click', this.hide);
    closeOutside.addEventListener('click', () => {
        closeButton.click();
    });
}

let fancyAlert = function(title, message, onClose) {
    let fa = new FancyDialog(title);

    let bm = document.createElement('p');
    bm.innerHTML = message;

    fa.content.appendChild(bm);
    fa.closeButton.setAttribute('value', 'OK');

    if(onClose && typeof onClose == "function") {
        fa.closeButton.addEventListener('click', onClose);
    }

    fa.show();
}

let fancyConfirm = function(title, message, onconfirm, ondecline) {
    let fa = new FancyDialog(title);

    let bm = document.createElement('p');
    bm.innerHTML = message;

    fa.content.appendChild(bm);
    fa.closeButton.setAttribute('value', 'No');
    if(ondecline) fa.closeButton.addEventListener('click', ondecline);

    let yb = document.createElement('input');
    yb.type = 'submit';
    yb.value = 'Yes'
    fa.buttons.appendChild(yb);
    yb.addEventListener('click', () => {
        onconfirm();
        fa.hide();    
    });

    fa.show();
}