# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ML Kit & Google Scanner (mobile_scanner)
-keep class com.google.mlkit.** { *; }

# WebRTC (flutter_webrtc)
-keep class org.webrtc.** { *; }

# Billing (in_app_purchase)
-keep class com.android.billingclient.** { *; }

# UCrop (Image Cropper)
-keep class com.yalantis.ucrop.** { *; }
-keep class com.yalantis.ucrop.view.** { *; }

# Home Widget plugin + Android widget components
-keep class es.antonborri.home_widget.** { *; }
# Các thành phần chính của App (Không được làm rối để Android tìm thấy Receiver/Widget)
-keep class com.soullocket.app.WidgetCoupleProvider { *; }
-keep class com.soullocket.app.DiaryImageRemoteViewsService { *; }
-keep class com.soullocket.app.MainActivity { *; }

# Các plugin phổ biến khác (tránh lỗi crash sau khi làm rối code)
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
