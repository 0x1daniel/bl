/* Copyright 2018, Daniel Oltmanns (https://github.com/oltdaniel) */

if(!document.cookie.includes('showed_cookie_banner=true')) {
  document.getElementsByTagName('header')[0].innerHTML += '<cookie-banner><p>Cookies  will only be used for authentication purposes. No personal information will be stored nor given to other parties.</p> <u onclick="document.cookie += \'showed_cookie_banner=true;path=/;\'; this.parentNode.remove();">Hide</u></cookie-banner>'
}
