##############################################
## Flutter y Plugins
##############################################
# Mantener todas las clases de Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Evitar advertencias de Flutter
-dontwarn io.flutter.embedding.**

##############################################
## Firebase
##############################################
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Evitar que se elimine Firebase Analytics
-keep class com.google.android.gms.measurement.** { *; }
-dontwarn com.google.android.gms.measurement.**

##############################################
## ML Kit
##############################################
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Evitar que se eliminen dependencias opcionales (idiomas, OCR, etc.)
-keep class com.google.mlkit.vision.text.** { *; }

##############################################
## Google Play Services
##############################################
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

##############################################
## Kotlin
##############################################
-keepclassmembers class ** {
    @kotlin.Metadata *;
}

-keep class kotlin.** { *; }
-dontwarn kotlin.**

##############################################
## Otras reglas comunes
##############################################
# Evitar la eliminación de clases con anotaciones
-keepattributes *Annotation*

# Evitar que se eliminen clases reflexionadas
-keep class * extends java.lang.annotation.Annotation { *; }

# Evitar la eliminación de clases usadas por name
-keepclassmembers class * {
    public <init>(...);
}
