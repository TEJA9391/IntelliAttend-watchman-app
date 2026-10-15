# Retain generic signatures (required for Gson and TypeToken)
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes *Annotation*

# Retain TypeToken and its subclasses
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# Optional: General Gson rules often recommended for this plugin
-dontwarn sun.misc.**
-keep class com.dexterous.** { *; }