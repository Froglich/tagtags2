function defaultErrorDialog(status, msg) {
    fancyAlert('Error ' + status, msg + '<br>Error ' + status + ' (' + statusCodes[status] + ')');
}

function fancyError(msg) {
    fancyAlert('An error has occurred', msg);
}