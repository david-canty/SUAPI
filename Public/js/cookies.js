function cookiesConfirmed() {
    
    $('#cookie-footer').hide();
    
    var date = new Date();
    date.setTime(date.getTime() + (365*24*60*60*1000));
    var expires = "expires="+ date.toUTCString();
    
    document.cookie = "cookies-accepted=true;" + expires;
}
