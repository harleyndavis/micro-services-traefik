from django.conf import settings


def assets_url(request):
    return {
        'ASSETS_URL':    settings.ASSETS_URL,
        'HOME_URL':      settings.HOME_URL,
        'SHORTENER_URL': settings.SHORTENER_URL,
        'QR_URL':        settings.QR_URL,
        'SITE_NAME':     settings.SITE_NAME,
        'SITE_TAGLINE':  settings.SITE_TAGLINE,
    }
