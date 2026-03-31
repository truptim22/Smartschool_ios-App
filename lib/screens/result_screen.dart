// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import 'pdf_viewer_page.dart';

class ResultScreen extends StatefulWidget {
  final int studentId;
  const ResultScreen({Key? key, required this.studentId}) : super(key: key);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? _resultData;
  bool _loading = true;
  String? _error;

  static const Color _primary      = Color(0xFF1d4ed8);
  static const Color _dark         = Color(0xFF1e3a8a);
  static const Color _bg           = Color(0xFFf0f4ff);
  static const Color _green        = Color(0xFF15803d);
  static const Color _red          = Color(0xFFdc2626);
  static const Color _amber        = Color(0xFFd97706);
  static const Color _amberBg      = Color(0xFFFFFBEB);
  static const Color _examColor    = Color(0xFF1e3a8a);
  static const Color _examSubColor = Color(0xFF1d4ed8);
  static const Color _totalColor   = Color(0xFF15803d);
  static const Color _reqColor     = Color(0xFFdc2626);
  static const Color _avgColor     = Color(0xFFd97706);

  static const double _subjectW  = 130;
  static const double _cellW     = 46;
  static const double _totalW    = 50;
  static const double _requiredW = 60;
  static const double _avgW      = 48;

  @override
  void initState() {
    super.initState();
    _fetchResult();
  }

  Future<void> _fetchResult() async {
    setState(() { _loading = true; _error = null; });
    final res = await ApiService.getStudentResult(widget.studentId);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _resultData = res['data']; _loading = false; });
    } else {
      setState(() { _error = res['message']; _loading = false; });
    }
  }
String _normalizePdfUrl(String url) {
  // Strip port 3001 - not publicly accessible
  if (url.contains(':3001')) {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      return 'https://lantechschools.org${uri.path}';
    }
  }
  if (url.startsWith('https://')) return url;
  if (url.startsWith('http://')) return url.replaceFirst('http://', 'https://');
  // Relative path
  final clean = url.startsWith('/') ? url.substring(1) : url;
  return 'https://lantechschools.org/$clean';
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _dark,
        foregroundColor: Colors.white,
        title: Text('Result', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchResult, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : _error != null ? _buildError() : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 72, color: Colors.grey[300]),
            SizedBox(height: 20),
            Text('No Results Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _fetchResult,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary, foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final student    = _resultData!['student']  as Map<String, dynamic>;
    final stats      = _resultData!['stats']    as Map<String, dynamic>;
    final subjects   = (_resultData!['subjects'] as List).cast<Map<String, dynamic>>();
    final attendance = _resultData!['attendance'];
    final sem2Done   = stats['sem2_done'] == true;
    final hasPdf     = _resultData!['has_pdf'] == true;
    final pdfUrl     = _resultData!['pdf_url'];

    return RefreshIndicator(
      onRefresh: _fetchResult,
      color: _primary,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(student, stats, attendance),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(stats, sem2Done),
                  SizedBox(height: 20),
                  if (!sem2Done) ...[
                    _buildNotice(
                      icon: Icons.info_outline,
                      color: _amber, bgColor: _amberBg,
                      borderColor: Color(0xFFFCD34D),
                      text: 'Semester 2 results have not been published yet. '
                          'Showing Semester 1 results only.',
                    ),
                    SizedBox(height: 16),
                  ],
                  _buildSectionTitle('Subject-wise Marks'),
                  SizedBox(height: 10),
                  _buildMarksTable(subjects, sem2Done),
                  SizedBox(height: 20),
                  _buildPdfAvailability(hasPdf, pdfUrl),
                  SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ONLY ONE _buildPdfAvailability ────────────────────────
  Widget _buildPdfAvailability(bool hasPdf, String? pdfUrl) {
    if (!hasPdf || pdfUrl == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Colors.grey[400], size: 22),
            SizedBox(width: 10),
            Text('Result PDF not uploaded yet',
                style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

   final fullUrl = _normalizePdfUrl(pdfUrl);

    final now = DateTime.now();
    final fileName = 'Result_${now.day}-${now.month}-${now.year}.pdf';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1d4ed8).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF1d4ed8).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF1d4ed8), size: 24),
            SizedBox(width: 12),
            Text('Result PDF',
                style: TextStyle(color: Color(0xFF1d4ed8), fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => PDFViewerPage(
                      filePath: fullUrl,
                      title: 'Result',
                      isLocalFile: false,
                    ),
                  ));
                },
                icon: Icon(Icons.visibility, size: 20),
                label: Text('View PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1d4ed8),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await DownloadService.downloadFile(
                    url: fullUrl,
                    fileName: fileName,
                    context: context,
                  );
                },
                icon: Icon(Icons.download, size: 20),
                label: Text('Download'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF1d4ed8),
                  side: BorderSide(color: Color(0xFF1d4ed8)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeader(Map student, Map stats, dynamic attendance) {
    final totalObt = (stats['total_obtained'] as num).toDouble();
    final totalMax = (stats['total_max']      as num).toDouble();
    final pct      = totalMax > 0 ? (totalObt / totalMax * 100) : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1e3a8a), Color(0xFF1d4ed8), Color(0xFF2563eb)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: Center(
                    child: Text((student['name'] ?? 'S')[0].toUpperCase(),
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student['name'] ?? '—',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 3),
                      Text('Class ${student['class']}${student['division']}  •  Roll No. ${student['roll_number']}',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
              SizedBox(height: 20),
              Wrap(spacing: 20, runSpacing: 10, children: [
                _headerChip('GR No',      student['gr_number']     ?? '—'),
                _headerChip('DOB',        student['date_of_birth'] ?? '—'),
                if (attendance != null)
                  _headerChip('Attendance', '${(attendance as num).toStringAsFixed(1)}%',
                      valueColor: attendance >= 75 ? Colors.greenAccent
                          : attendance >= 60 ? Colors.orangeAccent : Colors.redAccent),
                _headerChip('Percentage', '${pct.toStringAsFixed(1)}%'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerChip(String label, String value, {Color? valueColor}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white38, fontSize: 9)),
      Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildStatsRow(Map stats, bool sem2Done) {
    final totalObt  = (stats['total_obtained']  as num).toDouble();
    final totalMax  = (stats['total_max']        as num).toDouble();
    final isPassing = stats['is_passing'] == true;
    final reqToPass = (stats['required_to_pass'] as num).toDouble();

    return Row(children: [
      Expanded(child: _statCard(
        label: 'Total Marks',
        value: '${totalObt.toStringAsFixed(0)} / ${totalMax.toStringAsFixed(0)}',
        icon: Icons.bar_chart_rounded, color: Color(0xFF4f46e5),
      )),
      SizedBox(width: 10),
      Expanded(child: _statCard(
        label: isPassing ? 'Status' : 'Need More',
        value: isPassing ? 'Passing ✓' : '+${reqToPass.abs().toStringAsFixed(0)}',
        icon: isPassing ? Icons.check_circle_outline : Icons.warning_amber_rounded,
        color: isPassing ? Color(0xFF15803d) : Color(0xFFdc2626),
      )),
      SizedBox(width: 10),
      Expanded(child: _statCard(
        label: sem2Done ? 'Exams Done' : 'Sem 2',
        value: sem2Done ? 'All 4' : 'Pending',
        icon: sem2Done ? Icons.done_all : Icons.hourglass_empty_rounded,
        color: sem2Done ? Color(0xFF0369a1) : Color(0xFFd97706),
      )),
    ]);
  }

  Widget _statCard({required String label, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        SizedBox(height: 6),
        Text(value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500]), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildMarksTable(List<Map<String, dynamic>> subjects, bool sem2Done) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: [
            _buildDoubleHeader(sem2Done),
            ...subjects.asMap().entries.map((e) => _buildDataRow(e.value, e.key, sem2Done)),
            _buildGrandTotalRow(subjects, sem2Done),
          ]),
        ),
      ),
    );
  }

  Widget _buildDoubleHeader(bool sem2Done) {
    final double examGroupW = _cellW * 2;

    Widget gl(String text, double width, Color bg) => Container(
        width: width, alignment: Alignment.center, color: bg,
        padding: EdgeInsets.symmetric(vertical: 7),
        child: Text(text, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.4)));

    Widget sl(String text, double width, Color bg) => Container(
        width: width, alignment: Alignment.center, color: bg,
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600)));

    Widget vd(Color bg) => Container(width: 1, height: 28, color: bg.withOpacity(0.4));

    return Column(children: [
      Row(children: [
        Container(
          width: _subjectW, height: 56,
          alignment: Alignment.centerLeft,
          color: _examColor, padding: EdgeInsets.only(left: 10),
          child: Text('SUBJECT', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            gl('UNIT 1', examGroupW, _examColor), vd(_examColor),
            gl('SEM 1',  examGroupW, _examColor), vd(_examColor),
            gl('UNIT 2', examGroupW, _examColor), vd(_examColor),
            gl(sem2Done ? 'SEM 2' : 'SEM 2*', examGroupW, _examColor), vd(_totalColor),
            gl('TOTAL',    _totalW * 2, _totalColor), vd(_reqColor),
            gl('REQUIRED', _requiredW,  _reqColor),   vd(_avgColor),
            gl('AVERAGE',  _avgW * 2,   _avgColor),
          ]),
          Row(children: [
            sl('Obt', _cellW, _examSubColor), sl('Max', _cellW, _examSubColor), vd(_examSubColor),
            sl('Obt', _cellW, _examSubColor), sl('Max', _cellW, _examSubColor), vd(_examSubColor),
            sl('Obt', _cellW, _examSubColor), sl('Max', _cellW, _examSubColor), vd(_examSubColor),
            sl('Obt', _cellW, _examSubColor), sl('Max', _cellW, _examSubColor), vd(Color(0xFF15803d)),
            sl('Obt', _totalW, Color(0xFF166534)), sl('Max', _totalW, Color(0xFF166534)), vd(Color(0xFFdc2626)),
            sl('Marks', _requiredW, Color(0xFFb91c1c)), vd(Color(0xFFd97706)),
            sl('Obt', _avgW, Color(0xFFb45309)), sl('Max', _avgW, Color(0xFFb45309)),
          ]),
        ]),
      ]),
    ]);
  }

  Widget _buildDataRow(Map<String, dynamic> sub, int index, bool sem2Done) {
    final isEven  = index % 2 == 0;
    final isGrace = (sub['mstat'] ?? '').toUpperCase() == 'G';
    final u1 = sub['unit1'] as Map<String, dynamic>;
    final s1 = sub['sem1']  as Map<String, dynamic>;
    final u2 = sub['unit2'] as Map<String, dynamic>;
    final s2 = sub['sem2']  as Map<String, dynamic>;
    final s2Done = s2['done'] == true;

    String v(dynamic val) {
      if (val == null) return '—';
      final d = (val as num).toDouble();
      return d.toStringAsFixed(d == d.truncateToDouble() ? 0 : 1);
    }

    Widget dc(String text, double w, {Color? color, bool bold = false}) => Container(
        width: w, alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: TextStyle(
            fontSize: 10,
            color: color ?? Color(0xFF374151),
            fontWeight: bold ? FontWeight.bold : FontWeight.w500)));

    Widget div() => Container(width: 1, height: 36, color: Colors.grey.shade200);

    final s1Obt = (s1['obtained'] as num? ?? 0).toDouble();
    final s1Max = (s1['max']      as num? ?? 0).toDouble();
    final s2Obt = s2Done ? (s2['obtained'] as num? ?? 0).toDouble() : 0.0;
    final s2Max = (s2['max']      as num? ?? 0).toDouble();
    final totObt = s1Obt + s2Obt;
    final totMax = s1Max + s2Max;
    final passing   = totMax * 0.35;
    final required  = passing - totObt;
    final isPassing = !isGrace && totMax > 0 && totObt >= passing;
    final avgObt    = totMax > 0 ? (totObt / totMax * 100) / 2 : 0.0;

    return Container(
      color: isEven ? Colors.white : const Color(0xFFf8faff),
      child: Row(children: [
        Container(
          width: _subjectW,
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sub['sub_name'] ?? '',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _dark),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            if (isGrace)
              Container(
                margin: EdgeInsets.only(top: 2),
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Color(0xFFede9fe), borderRadius: BorderRadius.circular(4)),
                child: Text('Grace', style: TextStyle(fontSize: 8, color: Color(0xFF5b21b6))),
              ),
          ]),
        ),
        dc(v(u1['obtained']), _cellW), dc(v(u1['max']), _cellW), div(),
        dc(v(s1['obtained']), _cellW, color: (s1['obtained'] as num? ?? 0) > 0 ? _primary : null, bold: (s1['obtained'] as num? ?? 0) > 0),
        dc(v(s1['max']), _cellW), div(),
        dc(v(u2['obtained']), _cellW), dc(v(u2['max']), _cellW), div(),
        dc(s2Done ? v(s2['obtained']) : '—', _cellW,
            color: s2Done && (s2['obtained'] as num? ?? 0) > 0 ? _primary : Colors.grey[400]),
        dc(v(s2['max']), _cellW), div(),
        if (isGrace) ...[
          Container(
            width: _totalW * 2, alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Color(0xFFede9fe), borderRadius: BorderRadius.circular(6)),
              child: Text('-', style: TextStyle(fontSize: 10, color: Color(0xFF5b21b6), fontWeight: FontWeight.bold)),
            ),
          ),
        ] else ...[
          Container(width: _totalW, alignment: Alignment.center,
              child: Text(totObt.toStringAsFixed(totObt == totObt.truncateToDouble() ? 0 : 1),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPassing ? _green : _red))),
          Container(width: _totalW, alignment: Alignment.center,
              child: Text(totMax.toStringAsFixed(0),
                  style: TextStyle(fontSize: 10, color: Color(0xFF6b7280), fontWeight: FontWeight.w500))),
        ],
        div(),
        Container(
          width: _requiredW, alignment: Alignment.center,
          child: isGrace || totMax == 0
              ? Text('—', style: TextStyle(color: Colors.grey, fontSize: 10))
              : Text(isPassing ? '✓' : '+${required.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPassing ? _green : _red)),
        ),
        div(),
        if (isGrace) ...[
          Container(width: _avgW * 2, alignment: Alignment.center,
              child: Text('—', style: TextStyle(color: Colors.grey, fontSize: 10))),
        ] else ...[
          Container(width: _avgW, alignment: Alignment.center,
              child: Text(avgObt.toStringAsFixed(1),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _amber))),
          Container(width: _avgW, alignment: Alignment.center,
              child: Text('100', style: TextStyle(fontSize: 10, color: Color(0xFF6b7280), fontWeight: FontWeight.w500))),
        ],
      ]),
    );
  }

  Widget _buildGrandTotalRow(List<Map<String, dynamic>> subjects, bool sem2Done) {
    double u1O=0,u1M=0, s1O=0,s1M=0, u2O=0,u2M=0, s2O=0,s2M=0;
    for (final sub in subjects) {
      if ((sub['mstat'] ?? '').toUpperCase() == 'G') continue;
      u1O += (sub['unit1']['obtained'] as num? ?? 0).toDouble();
      u1M += (sub['unit1']['max']      as num? ?? 0).toDouble();
      s1O += (sub['sem1']['obtained']  as num? ?? 0).toDouble();
      s1M += (sub['sem1']['max']       as num? ?? 0).toDouble();
      u2O += (sub['unit2']['obtained'] as num? ?? 0).toDouble();
      u2M += (sub['unit2']['max']      as num? ?? 0).toDouble();
      if (sub['sem2']['done'] == true) {
        s2O += (sub['sem2']['obtained'] as num? ?? 0).toDouble();
      }
      s2M += (sub['sem2']['max'] as num? ?? 0).toDouble();
    }
    final totO = s1O + s2O;
    final totM = s1M + s2M;

    String f(double val) => val.toStringAsFixed(val == val.truncateToDouble() ? 0 : 1);

    Widget tc(String text, double w) => Container(
        width: w, alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)));

    Widget div() => Container(width: 1, height: 40, color: Colors.white.withOpacity(0.15));

    return Container(
      decoration: BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      ),
      child: Row(children: [
        Container(width: _subjectW, padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Text('TOTAL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
        tc(f(u1O), _cellW), tc(f(u1M), _cellW), div(),
        tc(f(s1O), _cellW), tc(f(s1M), _cellW), div(),
        tc(f(u2O), _cellW), tc(f(u2M), _cellW), div(),
        tc(sem2Done ? f(s2O) : '—', _cellW), tc(f(s2M), _cellW), div(),
        Container(
          width: _totalW * 2, alignment: Alignment.center,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('${f(totO)} / ${f(totM)}',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        div(),
        tc('—', _requiredW), div(),
        tc('—', _avgW), tc('—', _avgW),
      ]),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(width: 4, height: 20,
          decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _dark)),
    ]);
  }

  Widget _buildNotice({required IconData icon, required Color color,
      required Color bgColor, required Color borderColor, required String text}) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12))),
      ]),
    );
  }
}