
#ifndef CHILITAGS_EXPORT_H
#define CHILITAGS_EXPORT_H

#ifdef CHILITAGS_STATIC_DEFINE
#  define CHILITAGS_EXPORT
#  define CHILITAGS_NO_EXPORT
#else
#  ifndef CHILITAGS_EXPORT
#    ifdef chilitags_EXPORTS
        /* We are building this library */
#      define CHILITAGS_EXPORT __attribute__((visibility("default")))
#    else
        /* We are using this library */
#      define CHILITAGS_EXPORT __attribute__((visibility("default")))
#    endif
#  endif

#  ifndef CHILITAGS_NO_EXPORT
#    define CHILITAGS_NO_EXPORT __attribute__((visibility("hidden")))
#  endif
#endif

#ifndef CHILITAGS_DEPRECATED
#  define CHILITAGS_DEPRECATED __attribute__ ((__deprecated__))
#endif

#ifndef CHILITAGS_DEPRECATED_EXPORT
#  define CHILITAGS_DEPRECATED_EXPORT CHILITAGS_EXPORT CHILITAGS_DEPRECATED
#endif

#ifndef CHILITAGS_DEPRECATED_NO_EXPORT
#  define CHILITAGS_DEPRECATED_NO_EXPORT CHILITAGS_NO_EXPORT CHILITAGS_DEPRECATED
#endif

#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef CHILITAGS_NO_DEPRECATED
#    define CHILITAGS_NO_DEPRECATED
#  endif
#endif

#endif
