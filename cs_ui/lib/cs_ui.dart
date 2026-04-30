/// cs_ui — cs_framework 配套视觉主题系统
///
/// 提供：
/// - [CsApp]：顶层应用 Widget，替换 MaterialApp，自动注入当前主题
/// - [CsAppTheme]：主题工厂，通过修改 [CsAppTheme.activeStyle] 切换风格
/// - [CsThemeStyle]：可用风格枚举（freshMinimal / cartoon / ...）
/// - [FreshMinimalTheme]、[CartoonTheme]：具体主题实现，可直接引用
/// - [CsImage]：**图片统一入口**，所有业务图片必须通过此 Widget 使用
/// - [CsPlaceholderImage]：无图源时的占位组件，通常由 [CsImage] 自动托管
/// - [CsLottie]：**Lottie 动画统一入口**，所有业务动画必须通过此 Widget 使用
/// - [CsPlaceholderLottie]：无动画源时的占位组件，通常由 [CsLottie] 自动托管
/// - [CsVideo]：**视频统一入口**，所有业务视频必须通过此 Widget 使用
/// - [CsPlaceholderVideo]：无视频源时的占位组件，通常由 [CsVideo] 自动托管
///
/// ## 接入示例
///
/// ```dart
/// import 'package:cs_ui/cs_ui.dart';
///
/// void main() {
///   runApp(const ProviderScope(child: MyApp()));
/// }
///
/// class MyApp extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return CsApp(
///       title: 'My App',
///       home: const HomeScreen(),
///     );
///   }
/// }
/// ```
///
/// ## 图片使用规范（必读）
///
/// 接入 cs_ui 的业务方，**所有图片必须使用 [CsImage]**，禁止直接使用
/// `Image.asset`、`Image.network` 或 `CachedNetworkImage`。
///
/// ```dart
/// // ✅ 正确：通过 CsImage 统一管理
/// CsImage(
///   configKey: 'home_banner_image',
///   description: '首页横幅',
///   width: double.infinity,
///   height: 200,
/// )
///
/// // ❌ 错误：禁止写死路径或 URL
/// Image.asset('assets/images/banner.png')
/// Image.network('https://example.com/banner.jpg')
/// CachedNetworkImage(imageUrl: 'https://example.com/banner.jpg')
/// ```
///
/// ## Lottie 动画使用规范（必读）
///
/// 接入 cs_ui 的业务方，**所有 Lottie 动画必须使用 [CsLottie]**，禁止直接使用
/// `Lottie.asset`、`Lottie.network`。
///
/// ```dart
/// // ✅ 正确：通过 CsLottie 统一管理
/// CsLottie(
///   configKey: 'home_loading_animation',
///   description: '首页加载动画',
///   width: 200,
///   height: 200,
/// )
///
/// // ❌ 错误：禁止写死路径或 URL
/// Lottie.asset('assets/animations/loading.json')
/// Lottie.network('https://example.com/animation.json')
/// ```
///
/// [CsLottie] 通过 `configKey` 从配置系统读取动画源，支持远程热更新（url 优先）、
/// 本地 asset 降级、无动画时自动显示与图片占位明显不同的 [CsPlaceholderLottie]。
/// 动画配置由 AI Skill `cs-lottie-manager` 统一管理。
///
/// ## 视频使用规范（必读）
///
/// 接入 cs_ui 的业务方，**所有视频必须使用 [CsVideo]**，禁止直接使用
/// `VideoPlayerController` 写死路径或 URL。
///
/// ```dart
/// // ✅ 正确：通过 CsVideo 统一管理
/// CsVideo(
///   configKey: 'home_intro_video',
///   description: '首页介绍视频',
///   width: double.infinity,
///   height: 200,
/// )
///
/// // ❌ 错误：禁止写死路径或 URL
/// VideoPlayerController.asset('assets/videos/intro.mp4')
/// VideoPlayerController.networkUrl(Uri.parse('https://example.com/video.mp4'))
/// ```
///
/// [CsVideo] 通过 `configKey` 从配置系统读取视频源，支持远程热更新（url 优先）、
/// 本地 asset 降级、无视频时自动显示 [CsPlaceholderVideo]。
/// 视频配置由 AI Skill `cs-video-manager` 统一管理。
library cs_ui;

export 'src/theme/cs_app_theme.dart';
export 'src/widgets/cs_app.dart';
export 'src/widgets/cs_app_bar.dart';
export 'src/widgets/cs_image.dart';
export 'src/widgets/cs_placeholder_image.dart';
export 'src/widgets/cs_lottie.dart';
export 'src/widgets/cs_placeholder_lottie.dart';
export 'src/widgets/cs_video.dart';
export 'src/widgets/cs_placeholder_video.dart';

// 认证 UI 组件
export 'src/auth/cs_login_form.dart';
export 'src/auth/cs_login_page.dart'
    show CsLoginPage, CsForgotPasswordPage, CsResetPasswordPage;

// 重新导出 shadcn_ui 核心，方便业务代码直接使用 ShadButton、ShadCard 等
// 而不需要在业务代码中单独引入 shadcn_ui 包
export 'package:shadcn_ui/shadcn_ui.dart';
