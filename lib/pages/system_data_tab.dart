import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fyp/widgets/filter_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SystemDataTab extends StatefulWidget {
  const SystemDataTab({super.key});

  @override
  State<SystemDataTab> createState() => _SystemDataTabState();
}

class _SystemDataTabState extends State<SystemDataTab> {
  String selectedTimeRange = 'Last 24 hours';
  String selectedDevice = 'Switch 1';
  String selectedSensor = 'All';
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
          FilterCard(
            onRefresh: () => setState(() {}),
            isDeviceOnline: true,
            selectedTimeRange: selectedTimeRange,
            selectedDevice: '', // Can be empty since not shown
            selectedSensor: selectedSensor,
            onTimeRangeChanged:
                (val) => setState(() => selectedTimeRange = val!),
            onDeviceChanged: (_) {}, // No-op
            onSensorChanged: (val) => setState(() => selectedSensor = val!),
            sensorOptions: const [
              'All',
              'CPU Usage',
              'Memory Usage',
              'Disk Usage',
              'Network Traffic',
            ],
            showDeviceDropdown: false,
          ),

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
                NotificationPieChart(bgColor: bgColor, textColor: textColor),
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
  String deviceStatus = 'offline';
  DateTime? lastUpdated;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    listenToDeviceStatus();
    fetchNetworkData();
  }

  void listenToDeviceStatus() {
    Supabase.instance.client
        .from('netstruct')
        .stream(primaryKey: ['uuid'])
        .order('timestamp', ascending: false)
        .limit(1)
        .listen(
          (data) {
            if (data.isNotEmpty && mounted) {
              final newStatus =
                  data.last['status']?.toString().toLowerCase() ?? 'offline';

              setState(() {
                deviceStatus = newStatus;
                if (newStatus == 'online') {
                  fetchNetworkData();
                } else {
                  _clearDataIfOffline();
                }
              });
            }
          },
          onError: (error) {
            debugPrint('Device status stream error: $error');
          },
        );
  }

  void _clearDataIfOffline() {
    setState(() {
      downloadSpots = [];
      uploadSpots = [];
      lastUpdated = null;
    });
  }

  Future<void> fetchNetworkData() async {
    if (deviceStatus != 'online') return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

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
        final dVal = _parseDouble(data[i]['download_kbps']) ?? 0;
        final uVal = _parseDouble(data[i]['upload_kbps']) ?? 0;
        dl.add(FlSpot(i.toDouble(), dVal));
        ul.add(FlSpot(i.toDouble(), uVal));
      }

      setState(() {
        downloadSpots = dl;
        uploadSpots = ul;
        isLoading = false;
        lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('Error fetching network data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load network data';
      });
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    try {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '').trim();
        return double.tryParse(cleaned);
      }
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    } catch (e) {
      debugPrint('Error parsing double from $value: $e');
      return null;
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
              Row(
                children: [
                  if (deviceStatus != 'online')
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: widget.textColor),
                    onPressed: fetchNetworkData,
                  ),
                ],
              ),
            ],
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                errorMessage!,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Last updated: ${DateFormat('MMM dd, HH:mm:ss').format(lastUpdated!)}',
                style: TextStyle(
                  color: widget.textColor.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ),
          Expanded(
            child:
                deviceStatus != 'online'
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            color: widget.textColor.withOpacity(0.5),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Device Offline',
                            style: TextStyle(
                              color: widget.textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                    : isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: widget.textColor),
                    )
                    : downloadSpots.isEmpty || uploadSpots.isEmpty
                    ? Center(
                      child: Text(
                        'No network data available',
                        style: TextStyle(color: widget.textColor),
                      ),
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
  String deviceStatus = 'offline';
  DateTime? lastUpdated;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    listenToDeviceStatus();
    fetchChartData();
  }

  void listenToDeviceStatus() {
    Supabase.instance.client
        .from('netstruct')
        .stream(primaryKey: ['uuid'])
        .order('timestamp', ascending: false)
        .limit(1)
        .listen(
          (data) {
            if (data.isNotEmpty && mounted) {
              final newStatus =
                  data.last['status']?.toString().toLowerCase() ?? 'offline';

              setState(() {
                deviceStatus = newStatus;
                if (newStatus == 'online') {
                  fetchChartData();
                } else {
                  _clearDataIfOffline();
                }
              });
            }
          },
          onError: (error) {
            debugPrint('Device status stream error: $error');
          },
        );
  }

  void _clearDataIfOffline() {
    setState(() {
      dataPoints = [];
      lastUpdated = null;
    });
  }

  Future<void> fetchChartData() async {
    if (deviceStatus != 'online') return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

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
        lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('Error fetching $column data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load ${widget.title} data';
      });
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
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
              Row(
                children: [
                  if (deviceStatus != 'online')
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: widget.textColor),
                    onPressed: fetchChartData,
                  ),
                ],
              ),
            ],
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                errorMessage!,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Last updated: ${DateFormat('MMM dd, HH:mm:ss').format(lastUpdated!)}',
                style: TextStyle(
                  color: widget.textColor.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ),
          Expanded(
            child:
                deviceStatus != 'online'
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            color: widget.textColor.withOpacity(0.5),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Device Offline',
                            style: TextStyle(
                              color: widget.textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                    : isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: widget.textColor),
                    )
                    : dataPoints.isEmpty
                    ? Center(
                      child: Text(
                        'No ${widget.title} data available',
                        style: TextStyle(color: widget.textColor),
                      ),
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
        ],
      ),
    );
  }
}

class NotificationPieChart extends StatefulWidget {
  final Color bgColor;
  final Color textColor;

  const NotificationPieChart({
    super.key,
    required this.bgColor,
    required this.textColor,
  });

  @override
  _NotificationPieChartState createState() => _NotificationPieChartState();
}

class _NotificationPieChartState extends State<NotificationPieChart> {
  List<PieChartSectionData> sections = [];
  bool isLoading = true;
  String deviceStatus = 'offline';
  DateTime? lastUpdated;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    listenToDeviceStatus();
    fetchNotificationData();
  }

  void listenToDeviceStatus() {
    Supabase.instance.client
        .from('netstruct')
        .stream(primaryKey: ['uuid'])
        .order('timestamp', ascending: false)
        .limit(1)
        .listen(
          (data) {
            if (data.isNotEmpty && mounted) {
              final newStatus =
                  data.last['status']?.toString().toLowerCase() ?? 'offline';

              setState(() {
                deviceStatus = newStatus;
                if (newStatus == 'online') {
                  fetchNotificationData();
                } else {
                  _clearDataIfOffline();
                }
              });
            }
          },
          onError: (error) {
            debugPrint('Device status stream error: $error');
          },
        );
  }

  void _clearDataIfOffline() {
    setState(() {
      sections = [];
      lastUpdated = null;
    });
  }

  Future<void> fetchNotificationData() async {
    if (deviceStatus != 'online') return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // TODO: Replace dummy data with actual Supabase query
      List<Map<String, dynamic>> data = [
        {'type': 'Error', 'count': 40},
        {'type': 'Warning', 'count': 30},

        {'type': 'Critical', 'count': 10},
      ];

      final List<PieChartSectionData> newSections = [];

      for (var entry in data) {
        final type = entry['type'];
        final count = entry['count'] as int;

        newSections.add(
          PieChartSectionData(
            value: count.toDouble(),
            color: _getColorForNotificationType(type),
            title: '$type\n$count',
            radius: 50,
            titleStyle: TextStyle(
              color: widget.textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }

      setState(() {
        sections = newSections;
        isLoading = false;
        lastUpdated = DateTime.now();
      });
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load notification data';
      });
    }
  }

  Color _getColorForNotificationType(String type) {
    switch (type.toLowerCase()) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.yellow;
      case 'info':
        return Colors.blue;
      case 'critical':
        return Colors.purple;
      default:
        return Colors.grey;
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
                'System Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
              ),
              Row(
                children: [
                  if (deviceStatus != 'online')
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: widget.textColor),
                    onPressed: fetchNotificationData,
                  ),
                ],
              ),
            ],
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                errorMessage!,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          if (lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Last updated: ${DateFormat('MMM dd, HH:mm:ss').format(lastUpdated!)}',
                style: TextStyle(
                  color: widget.textColor.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ),
          Expanded(
            child:
                deviceStatus != 'online'
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            color: widget.textColor.withOpacity(0.5),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Device Offline',
                            style: TextStyle(
                              color: widget.textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                    : isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: widget.textColor),
                    )
                    : sections.isEmpty
                    ? Center(
                      child: Text(
                        'No notification data available',
                        style: TextStyle(color: widget.textColor),
                      ),
                    )
                    : PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
