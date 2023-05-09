import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lionsmarket/msg_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebviewController extends StatefulWidget {
  const WebviewController({Key? key}) : super(key: key);

  @override
  State<WebviewController> createState() => _WebviewControllerState();
}

class _WebviewControllerState extends State<WebviewController> {
  // Initialize URL
  final String url = "https://lionsmarket.co.kr/";
  bool isInMainPage = true;

  // Initialize Webview Controller
  late InAppWebViewController _viewController;
  final GlobalKey webViewKey = GlobalKey();

  final MsgController _msgController = Get.put(MsgController());

  // Initialize GPS
  Position? _position;

  @override
  void initState() {
    super.initState();

    _requestPermission();
    _requestStoragePermission();
  }

  Future<void> _clearCache() async {
    await _viewController.clearCache();
  }

  // 위치 권한 요청
  Future<void> _requestPermission() async {
    final status = await Geolocator.checkPermission();

    if (status == LocationPermission.denied) {
      await Geolocator.requestPermission();
    } else if (status == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("위치 권한 요청이 거부되었습니다.")));
      return;
    }

    await _updatePosition();
  }

  Future<void> _updatePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _position = position;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("위치 정보를 받아오는 데 실패했습니다.")));
    }
  }

  void _requestStoragePermission() async {
    PermissionStatus status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      PermissionStatus result =
          await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        if (kDebugMode) {
          print('접근 권한이 거부되었습니다.');
        }
      }
    }
  }

  Future<String> _getCookies(InAppWebViewController controller) async {
    final String? cookies =
        await controller.evaluateJavascript(source: 'document.cookie;');
    return cookies ?? '';
  }

  Future<void> _setCookies(
      InAppWebViewController controller, String cookies) async {
    await controller.evaluateJavascript(source: 'document.cookie="$cookies";');
  }

  Future<void> _saveCookies(String cookies) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', cookies);
  }

  Future<String?> _loadCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('cookies');
  }

  UserScript get flutterWebviewProUserScript {
    return UserScript(source: """
          (function() {
            window.flutterWebviewPro = {
              postMessage: function(data) {
                console.log('flutterWebviewPro:' + JSON.stringify(data));
              }
            };
          })();
          """, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START);
  }

  void handleWebviewConsoleMessage(ConsoleMessage consoleMessage) async {
    final String message = consoleMessage.message;
    if (message.startsWith("flutterWebviewPro:")) {
      final String jsonDataString = message.substring(18);
      Map<String, dynamic> jsonData = jsonDecode(jsonDataString);

      if (jsonData['handler'] == 'webviewJavaScriptHandler') {
        if (jsonData['action'] == 'setUserId') {
          String userId = jsonData['data']['userId'];
          GetStorage().write('userId', userId);

          if (kDebugMode) {
            print('@addJavaScriptHandler userId $userId');
          }

          String? token = await _getPushToken();
          _viewController.evaluateJavascript(source: 'tokenUpdate("$token")');
        }
      }
    }
  }

  Future<String?> _getPushToken() async {
    return await _msgController.getToken();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: InAppWebView(
        initialUrlRequest: URLRequest(
          url: Uri.parse(url),
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: true,
            userAgent:
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
            useShouldOverrideUrlLoading: true,
            supportZoom: true,
            verticalScrollBarEnabled: true,
            cacheEnabled: true,
            clearCache: true,
            allowFileAccessFromFileURLs: true,
          ),
          android: AndroidInAppWebViewOptions(
            geolocationEnabled: true,
            thirdPartyCookiesEnabled: true,
          ),
          ios: IOSInAppWebViewOptions(
            allowsInlineMediaPlayback: true,
          ),
        ),
        onWebViewCreated: (InAppWebViewController controller) async {
          _viewController = controller;
          _clearCache(); // Invalidate Cache
          controller.getUrl().then(
            (url) {
              if (url.toString() == "https://lionsmarket.co.kr/") {
                setState(() {
                  isInMainPage = true;
                });
              } else {
                setState(() {
                  isInMainPage = false;
                });
              }
            },
          );
        },
        onLoadStart: (controller, url) async {
          if (kDebugMode) {
            print("Current page: $url");
          }
        },
        onLoadStop: (InAppWebViewController controller, Uri? url) async {
          if (url != null &&
              url.toString().contains("https://lionsmarket.co.kr")) {
            await _viewController.evaluateJavascript(source: """
              (function() {
                      function scrollToFocusedInput(event) {
                        const focusedElement = document.activeElement;
                        if (focusedElement.tagName.toLowerCase() === 'input' || focusedElement.tagName.toLowerCase() === 'textarea') {
                          setTimeout(() => {
                            focusedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                          }, 500);
                        }
                      }
            
                      document.addEventListener('focus', scrollToFocusedInput, true);
                    })();
            """);
          }

          if (url != null &&
              url
                  .toString()
                  .contains("https://lionsmarket.co.kr/bbs/login.php")) {
            await _viewController.evaluateJavascript(source: """
              async function loadScript() {
                        return new Promise((resolve, reject) => {
                            const script = document.createElement('script');
                            script.type = 'text/javascript';
                            script.src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=e3fa10c5c3f32ff65a8f50b5b7da847b&libraries=services';
                            script.onload = () => resolve();
                            script.onerror = () => reject(new Error('Failed to load the script'));
                            document.head.appendChild(script);
                        });
                    }
                    
                    var map;
                    var geocoder = new kakao.maps.services.Geocoder();
                    
                    function getCurrentPosition() {
                        return new Promise((resolve, reject) => {
                            navigator.geolocation.getCurrentPosition(resolve, reject);
                        });
                    }
                    
                    async function initMap() {
                        try {
                            const position = await getCurrentPosition();
                            var lat = position.coords.latitude;
                            var lon = position.coords.longitude;
                            var locPosition = new kakao.maps.LatLng(lat, lon);
                    
                            var mapContainer = document.getElementById('map'),
                                mapOption = {
                                    center: locPosition,
                                    level: 4
                                };
                    
                            map = new kakao.maps.Map(mapContainer, mapOption);
                        } catch (error) {
                            console.error("Error in initMap:", error);
                        }
                    }
                    
                    function getDistrict(address) {
                        var district = "";
                        var splitAddr = address.split(' ');
                    
                        if (splitAddr.length > 1) {
                            district = splitAddr[1];
                        }
                    
                        return district;
                    }
                    
                    async function storeLocation() {
                        try {
                            const position = await getCurrentPosition();
                            var lat = position.coords.latitude;
                            var lon = position.coords.longitude;
                            var locPosition = new kakao.maps.LatLng(lat, lon);
                    
                            var marker = new kakao.maps.Marker({
                                map: map,
                                position: locPosition
                            });
                    
                            map.setCenter(locPosition);
                    
                            geocoder.coord2Address(locPosition.getLng(), locPosition.getLat(), function (result, status) {
                                if (status === kakao.maps.services.Status.OK) {
                                    var detailAddr = result[0].address.address_name;
                                    var district = getDistrict(detailAddr);
                                    setLocation(locPosition.getLat(), locPosition.getLng(), detailAddr, district);
                                }
                            });
                        } catch (error) {
                            console.error("Error in storeLocation:", error);
                        }
                    }
                    
                    function setLocation(lat, lon, addr, district) {
                        document.getElementById('latitude').value = lat;
                        document.getElementById('longitude').value = lon;
                        document.getElementById('addr').value = addr;
                        document.getElementById('district').value = district;
                    }
                    
                    async function initApp() {
                        await initMap();
                        storeLocation();
                    }
                    
                    async function runApp() {
                        try {
                            await loadScript();
                            initApp();
                        } catch (error) {
                            console.error("Error in runApp:", error);
                        }
                    }
                    
                    runApp();
            """);

            final cookies = await _getCookies(_viewController);
            await _saveCookies(cookies);
          } else {
            final cookies = await _loadCookies();

            if (cookies != null) {
              await _setCookies(_viewController, cookies);
            }
          }
        },
        // ignore: prefer_collection_literals
        gestureRecognizers: Set()
          ..add(
            Factory<DragGestureRecognizer>(
              () => PanGestureRecognizer(),
            ),
          ),
      ),
    );
  }
}
