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
                  selectedTimeRange: selectedTimeRange,
                  selectedSensor: selectedSensor,
                ),
                CpuMemoryLineChart(
                  title: 'Memory Usage',
                  lineColor: Colors.blue,
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedSensor: selectedSensor,
                ),
                CpuMemoryLineChart(
                  title: 'Disk Usage',
                  lineColor: Colors.green,
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedSensor: selectedSensor,
                ),
                NotificationPieChart(
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedSensor: selectedSensor,
                ),
                NetworkTrafficChart(
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedSensor: selectedSensor,
                ),
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
  final String selectedTimeRange;
  final String selectedSensor;

  const NetworkTrafficChart({
    super.key,
    required this.bgColor,
    required this.textColor,
    required this.selectedTimeRange,
    required this.selectedSensor,
  });

  @override
  State<NetworkTrafficChart> createState() => _NetworkTrafficChartState();
}

class _NetworkTrafficChartState extends State<NetworkTrafficChart> {
  List<FlSpot> downloadSpots = [];
  List<FlSpot> uploadSpots = [];
  Map<double, String> xLabels = {};
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

  @override
  void didUpdateWidget(covariant NetworkTrafficChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If filter parameters changed, refresh data
    if (oldWidget.selectedTimeRange != widget.selectedTimeRange ||
        oldWidget.selectedSensor != widget.selectedSensor) {
      fetchNetworkData();
    }
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
      xLabels = {};
      lastUpdated = null;
    });
  }

  // Helper method to calculate time range for filtering
  DateTime _getStartTimeForRange(String timeRange) {
    final now = DateTime.now();

    switch (timeRange) {
      case 'Last hour':
        return now.subtract(const Duration(hours: 1));
      case 'Last 6 hours':
        return now.subtract(const Duration(hours: 6));
      case 'Last 12 hours':
        return now.subtract(const Duration(hours: 12));
      case 'Last 24 hours':
        return now.subtract(const Duration(hours: 24));
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 30));
      default:
        return now.subtract(const Duration(hours: 24));
    }
  }

  Future<void> fetchNetworkData() async {
    // Skip if sensor is not selected and not "All"
    if (widget.selectedSensor != 'All' &&
        widget.selectedSensor != 'Network Traffic') {
      setState(() {
        isLoading = false;
        downloadSpots = [];
        uploadSpots = [];
        xLabels = {};
        lastUpdated = DateTime.now();
      });
      return;
    }

    if (deviceStatus != 'online') return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Calculate time range
      final startTime = _getStartTimeForRange(widget.selectedTimeRange);
      final startTimeStr = startTime.toIso8601String();

      // Build query based on filters
      var query = supabase
          .from('infrastructure')
          .select('timestamp, download_kbps, upload_kbps')
          .gte('timestamp', startTimeStr)
          .order('timestamp', ascending: true);

      final response = await query;

      final data = response;
      final List<FlSpot> dl = [];
      final List<FlSpot> ul = [];
      final Map<double, String> labels = {};

      for (int i = 0; i < data.length; i++) {
        final dVal = _parseDouble(data[i]['download_kbps']) ?? 0;
        final uVal = _parseDouble(data[i]['upload_kbps']) ?? 0;
        dl.add(FlSpot(i.toDouble(), dVal));
        ul.add(FlSpot(i.toDouble(), uVal));

        final timestamp = DateTime.parse(data[i]['timestamp']);
        final timeLabel = DateFormat('HH:mm').format(timestamp);
        labels[i.toDouble()] = timeLabel;
      }

      setState(() {
        downloadSpots = dl;
        uploadSpots = ul;
        xLabels = labels;
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
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: calculateInterval(downloadSpots),
                              getTitlesWidget: (value, _) {
                                final label = xLabels[value];
                                return Transform.rotate(
                                  angle: -1.57,
                                  child: Text(
                                    label ?? '',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: widget.textColor.withOpacity(0.6),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
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

  double calculateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return 1;
    final first = spots.first.x;
    final last = spots.last.x;
    final total = last - first;
    return total / 4;
  }
}

class CpuMemoryLineChart extends StatefulWidget {
  final String title;
  final Color lineColor;
  final Color bgColor;
  final Color textColor;
  final String selectedTimeRange;
  final String selectedSensor;

  const CpuMemoryLineChart({
    super.key,
    required this.title,
    required this.lineColor,
    required this.bgColor,
    required this.textColor,
    required this.selectedTimeRange,
    required this.selectedSensor,
  });

  @override
  State<CpuMemoryLineChart> createState() => _CpuMemoryLineChartState();
}

class _CpuMemoryLineChartState extends State<CpuMemoryLineChart> {
  List<FlSpot> dataPoints = [];
  Map<double, String> xLabels = {};
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

  @override
  void didUpdateWidget(covariant CpuMemoryLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If filter parameters changed, refresh data
    if (oldWidget.selectedTimeRange != widget.selectedTimeRange ||
        oldWidget.selectedSensor != widget.selectedSensor) {
      fetchChartData();
    }
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
      xLabels = {};
      lastUpdated = null;
    });
  }

  // Helper method to calculate time range for filtering
  DateTime _getStartTimeForRange(String timeRange) {
    final now = DateTime.now();

    switch (timeRange) {
      case 'Last hour':
        return now.subtract(const Duration(hours: 1));
      case 'Last 6 hours':
        return now.subtract(const Duration(hours: 6));
      case 'Last 12 hours':
        return now.subtract(const Duration(hours: 12));
      case 'Last 24 hours':
        return now.subtract(const Duration(hours: 24));
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 30));
      default:
        return now.subtract(const Duration(hours: 24));
    }
  }

  Future<void> fetchChartData() async {
    // Skip if sensor is not selected and not "All"
    final title = widget.title.toLowerCase();
    if (widget.selectedSensor != 'All' &&
        widget.selectedSensor.toLowerCase() != title) {
      setState(() {
        isLoading = false;
        dataPoints = [];
        xLabels = {};
        lastUpdated = DateTime.now();
      });
      return;
    }

    if (deviceStatus != 'online') return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final supabase = Supabase.instance.client;

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
      // Calculate time range
      final startTime = _getStartTimeForRange(widget.selectedTimeRange);
      final startTimeStr = startTime.toIso8601String();

      // Build query based on filters
      var query = supabase
          .from('infrastructure')
          .select('timestamp, $column')
          .gte('timestamp', startTimeStr)
          .order('timestamp', ascending: true);

      final response = await query;

      final List data = response;
      final List<FlSpot> points = [];
      final Map<double, String> labels = {};

      for (int i = 0; i < data.length; i++) {
        final raw = data[i][column];
        if (raw == null) continue;

        final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(raw.toString());
        final value = match != null ? double.tryParse(match.group(0)!) : null;

        if (value != null) {
          points.add(FlSpot(i.toDouble(), value));

          final timestamp = DateTime.parse(data[i]['timestamp']);
          final timeLabel = DateFormat('HH:mm').format(timestamp);
          labels[i.toDouble()] = timeLabel;
        }
      }

      setState(() {
        dataPoints = points;
        xLabels = labels;
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
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: calculateInterval(dataPoints),
                              getTitlesWidget: (value, _) {
                                final label = xLabels[value];
                                return Transform.rotate(
                                  angle: -1.57,
                                  child: Text(
                                    label ?? '',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: widget.textColor.withOpacity(0.6),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
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

  double calculateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return 1;
    final first = spots.first.x;
    final last = spots.last.x;
    final total = last - first;
    return total / 4;
  }
}

class NotificationPieChart extends StatefulWidget {
  final Color bgColor;
  final Color textColor;
  final String selectedTimeRange;
  final String selectedSensor;

  const NotificationPieChart({
    super.key,
    required this.bgColor,
    required this.textColor,
    required this.selectedTimeRange,
    required this.selectedSensor,
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

  @override
  void didUpdateWidget(covariant NotificationPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If filter parameters changed, refresh data
    if (oldWidget.selectedTimeRange != widget.selectedTimeRange ||
        oldWidget.selectedSensor != widget.selectedSensor) {
      fetchNotificationData();
    }
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

  // Helper method to calculate time range for filtering
  DateTime _getStartTimeForRange(String timeRange) {
    final now = DateTime.now();

    switch (timeRange) {
      case 'Last hour':
        return now.subtract(const Duration(hours: 1));
      case 'Last 6 hours':
        return now.subtract(const Duration(hours: 6));
      case 'Last 12 hours':
        return now.subtract(const Duration(hours: 12));
      case 'Last 24 hours':
        return now.subtract(const Duration(hours: 24));
      case 'Last 7 days':
        return now.subtract(const Duration(days: 7));
      case 'Last 30 days':
        return now.subtract(const Duration(days: 30));
      default:
        return now.subtract(const Duration(hours: 24));
    }
  }

  Future<void> fetchNotificationData() async {
    // Skip if sensor is not selected and not "All"
    if (widget.selectedSensor != 'All') {
      setState(() {
        isLoading = false;
        sections = [];
        lastUpdated = DateTime.now();
      });
      return;
    }

    if (deviceStatus != 'online') return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Calculate time range
      final startTime = _getStartTimeForRange(widget.selectedTimeRange);
      final startTimeStr = startTime.toIso8601String();

      // TODO: Replace dummy data with actual Supabase query
      // This should query your notifications table with time filter
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
