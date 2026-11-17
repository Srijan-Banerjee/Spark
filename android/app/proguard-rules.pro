# WorkManager
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Room Database
-keep class * extends androidx.room.RoomDatabase { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.room.paging.** { *; }
-dontwarn androidx.work.impl.**
-dontwarn androidx.room.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Flutter and plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Spark Native
-keep class com.spark.spark.** { *; }
