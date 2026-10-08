import '../utils/app_scroll_behavior.dart' show kSelectableTextPhysics;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/installation_diagnostics.dart';
import '../services/api_base.dart';

/// Diagnostic data leaves the installation only after an explicit report.
class DiagnosisTile extends StatefulWidget {
  final String locale;
  const DiagnosisTile({super.key, required this.locale});
  @override
  State<DiagnosisTile> createState() => _DiagnosisTileState();
}

class _DiagnosisTileState extends State<DiagnosisTile> {
  late Future<Map<String, Object>> _snapshot;
  bool _reportBusy = false;
  String t(String en, String hans, String hant) => widget.locale == 'zh-Hans'
      ? hans
      : widget.locale == 'zh-Hant'
          ? hant
          : en;
  @override
  void initState() {
    super.initState();
    _snapshot = InstallationDiagnostics.snapshot();
  }

  Future<void> _report(Map<String, Object> data) async {
    if (_reportBusy) return;
    setState(() => _reportBusy = true);
    try {
      await _sendReport(data);
    } finally {
      if (mounted) setState(() => _reportBusy = false);
    }
  }

  Future<void> _sendReport(Map<String, Object> data) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(t('Send a diagnostic report', '发送诊断反馈', '傳送診斷回饋')),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(t(
                    'Your message, diagnosis ID, app version and delivery channel will be sent to the administrator. Do not include passwords or API keys.',
                    '将向管理员发送你的问题描述、诊断编号、应用版本和更新渠道。请勿填写密码或 API key。',
                    '將向管理員傳送問題描述、診斷編號、應用版本和更新管道。請勿填寫密碼或 API key。')),
                const SizedBox(height: 12),
                TextField(
                    controller: controller,
                    maxLength: 3000,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                        labelText:
                            t('What happened?', '遇到了什么问题？', '遇到了什麼問題？'))),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('Cancel', '取消', '取消'))),
                TextButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(context, controller.text.trim());
                      }
                    },
                    child: Text(t('Send', '发送', '傳送')))
              ],
            ));
    // Keep the controller alive until the dialog's closing animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (message == null || !mounted) return;
    InstallationDiagnostics.record('report', 'started');
    bool ok = false;
    try {
      final response = await http
          .post(Uri.parse(resolveApiUrl('/api/submitFeedback')),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'category': 'diagnostic',
                'message': message,
                'diagnostics': await InstallationDiagnostics.snapshot()
              }))
          .timeout(const Duration(seconds: 15));
      ok = response.statusCode == 200;
    } catch (_) {/* The report failure never affects the app. */}
    InstallationDiagnostics.record('report', ok ? 'succeeded' : 'failed');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? t('Report sent.', '反馈已发送。', '回饋已傳送。')
            : t('Could not send. Please try again or contact support.',
                '发送失败，请重试或联系支持。', '傳送失敗，請重試或聯絡支援。'))));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object>>(
        future: _snapshot,
        builder: (context, snapshot) {
          final data = snapshot.data;
          return Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('Diagnosis ID', '诊断编号', '診斷編號'),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SelectableText(data?['diagnosisId'] as String? ?? '…',
                            scrollPhysics: kSelectableTextPhysics,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: (Theme.of(context)
                                              .textTheme
                                              .bodyMedium!
                                              .fontSize! *
                                          0.85)
                                      .clamp(14.0, double.infinity),
                                )),
                        const SizedBox(height: 8),
                        Text(t(
                            'Random ID for this installation or browser. Shared only when you send feedback. Reinstalling or clearing browser data may change it.',
                            '此安装或浏览器的随机编号，仅在发送反馈时分享。重装或清除浏览器数据后可能改变。',
                            '此安裝或瀏覽器的隨機編號，僅在傳送回饋時分享。重裝或清除瀏覽器資料後可能改變。')),
                        if (data?['idPersistent'] == false)
                          Text(t(
                              'Storage unavailable: this ID lasts for this session.',
                              '存储不可用：此编号仅在本次运行有效。',
                              '儲存不可用：此編號僅在本次執行有效。')),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          TextButton.icon(
                              onPressed: data == null || _reportBusy
                                  ? null
                                  : () async {
                                      await Clipboard.setData(ClipboardData(
                                          text: const JsonEncoder.withIndent(
                                                  '  ')
                                              .convert(
                                                  await InstallationDiagnostics
                                                      .snapshot())));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(t(
                                                    'Copied', '已复制', '已複製'))));
                                      }
                                    },
                              icon: const Icon(Icons.copy),
                              label:
                                  Text(t('Copy details', '复制诊断信息', '複製診斷資訊'))),
                          TextButton.icon(
                              onPressed: data == null || _reportBusy
                                  ? null
                                  : () => _report(data),
                              icon: const Icon(Icons.feedback_outlined),
                              label:
                                  Text(t('Report a problem', '反馈问题', '回饋問題'))),
                          TextButton(
                              onPressed: data == null || _reportBusy
                                  ? null
                                  : () async {
                                      final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                                  title: Text(t(
                                                      'Reset diagnosis ID?',
                                                      '重置诊断编号？',
                                                      '重設診斷編號？')),
                                                  content: Text(t(
                                                      'Future reports will use a new ID. Previously sent reports are retained in the admin inbox.',
                                                      '以后反馈将使用新编号，已发送的反馈仍保留在后台收件箱。',
                                                      '以後回饋將使用新編號，已傳送的回饋仍保留在後台收件匣。')),
                                                  actions: [
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, false),
                                                        child: Text(t('Cancel',
                                                            '取消', '取消'))),
                                                    TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context, true),
                                                        child: Text(t('Reset',
                                                            '重置', '重設')))
                                                  ]));
                                      if (confirmed != true) return;
                                      await InstallationDiagnostics.reset();
                                      if (mounted) {
                                        setState(() => _snapshot =
                                            InstallationDiagnostics.snapshot());
                                      }
                                    },
                              child: Text(t('Reset ID', '重置编号', '重設編號'))),
                        ]),
                      ])));
        },
      );
}
