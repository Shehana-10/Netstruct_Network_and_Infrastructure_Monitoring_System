import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SystemDataTab extends StatefulWidget {
  const SystemDataTab({super.key});

  @override
  State<SystemDataTab> createState() => _SystemDataTabState();
}

class _SystemDataTabState extends State<SystemDataTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 800 ? 2 : 1;
    final bgColor = isDark ? const Color(0xFF161B22) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "System Metrics",
            style: TextStyle(
              fontSize: 20,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                CpuMemoryLineChart(
                  title: 'CPU Usage',
                  lineColor: Colors.red,
                  bgColor: bgColor,
                  textColor: textColor,
                ),
                CpuMemoryLineChart(
                  title: 'Memory Usage',
                  lineColor: Colors.blue,
                  bgColor: bgColor,
                  textColor: textColor,
                ),
                CpuMemoryLineChart(
                  title: 'Disk Usage',
                  lineColor: Colors.green,
                  bgColor: bgColor,
                  textColor: textColor,
                ),
                // Pie chart removed
                NetworkTrafficChart(bgColor: bgColor, textColor: textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkTrafficChart extends StatefulWidget {
  final Color bgColor;
  final Color textColor;

  const NetworkTrafficChart({
    super.key,
    required this.bgColor,
    required this.textColor,
  });

  @override
  State<NetworkTrafficChart> createState() => _NetworkTrafficChartState();
}

class _NetworkTrafficChartState extends State<NetworkTrafficChart> {
  List<FlSpot> downloadSpots = [];
  List<FlSpot> uploadSpots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNetworkData();
  }

  Future<void> fetchNetworkData() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('infrastructure')
          .select('timestamp, download_kbps, upload_kbps')
          .order('timestamp', ascending: false)
          .limit(50);

      final data = response.reversed.toList();
      final List<FlSpot> dl = [];
      final List<FlSpot> ul = [];

      for (int i = 0; i < data.length; i++) {
        final dVal = double.tryParse(data[i]['download_kbps'].toString()) ?? 0;
        final uVal = double.tryParse(data[i]['upload_kbps'].toString()) ?? 0;
        dl.add(FlSpot(i.toDouble(), dVal));
        ul.add(FlSpot(i.toDouble(), uVal));
      }

      setState(() {
        downloadSpots = dl;
        uploadSpots = ul;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching network data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Network Traffic (Kbps)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: widget.textColor),
                onPressed: fetchNetworkData,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: widget.textColor),
                    )
                    : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: downloadSpots,
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.blue.withOpacity(0.3),
                                  Colors.blue.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                          LineChartBarData(
                            spots: uploadSpots,
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.green.withOpacity(0.3),
                                  Colors.green.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class CpuMemoryLineChart extends StatefulWidget {
  final String title;
  final Color lineColor;
  final Color bgColor;
  final Color textColor;

  const CpuMemoryLineChart({
    super.key,
    required this.title,
    required this.lineColor,
    required this.bgColor,
    required this.textColor,
  });

  @override
  State<CpuMemoryLineChart> createState() => _CpuMemoryLineChartState();
}

class _CpuMemoryLineChartState extends State<CpuMemoryLineChart> {
  List<FlSpot> dataPoints = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchChartData();
  }

  Future<void> fetchChartData() async {
    final supabase = Supabase.instance.client;
    final title = widget.title.toLowerCase();

    String? column;
    if (title.contains('cpu')) {
      column = 'cpu';
    } else if (title.contains('memory')) {
      column = 'memory';
    } else if (title.contains('disk')) {
      column = 'disk';
    }

    if (column == null) return;

    try {
      final response = await supabase
          .from('infrastructure')
          .select('timestamp, $column')
          .order('timestamp', ascending: false)
          .limit(50);

      final List data = response;
      final List<FlSpot> points = [];

      for (int i = data.length - 1; i >= 0; i--) {
        final raw = data[i][column];
        if (raw == null) continue;

        final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(raw.toString());
        final value = match != null ? double.tryParse(match.group(0)!) : null;

        if (value != null) {
          points.add(FlSpot((data.length - 1 - i).toDouble(), value));
        }
      }

      setState(() {
        dataPoints = points;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching $column data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: widget.textColor),
                    )
                    : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: dataPoints,
                            isCurved: true,
                            barWidth: 2.5,
                            color: widget.lineColor,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  widget.lineColor.withOpacity(0.4),
                                  widget.lineColor.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
          if (!isLoading)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.refresh, color: widget.textColor),
                onPressed: fetchChartData,
              ),
            ),
        ],
      ),
    );
  }
}
