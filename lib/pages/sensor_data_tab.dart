import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:fyp/widgets/filter_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SensorDataTab extends StatefulWidget {
  const SensorDataTab({super.key});

  @override
  State<SensorDataTab> createState() => _SensorDataTabState();
}

class _SensorDataTabState extends State<SensorDataTab> {
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
            "Sensor Metrics",
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
            selectedDevice: selectedDevice,
            selectedSensor: selectedSensor,
            onTimeRangeChanged:
                (val) => setState(() => selectedTimeRange = val!),
            onDeviceChanged: (val) => setState(() => selectedDevice = val!),
            onSensorChanged: (val) => setState(() => selectedSensor = val!),
            sensorOptions: const [
              'All',
              'Temperature',
              'Humidity',
              'Gas',
              'Sound',
              'Flame',
              'Vibration',
            ],
          ),

          Expanded(
            child: GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                SensorLineChart(
                  title: 'Temperature',
                  lineColor: Colors.orange,
                  unit: '°C',
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedDevice: selectedDevice,
                  selectedSensor: selectedSensor,
                ),
                SensorLineChart(
                  title: 'Humidity',
                  lineColor: Colors.blue,
                  unit: '%',
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedDevice: selectedDevice,
                  selectedSensor: selectedSensor,
                ),
                SensorLineChart(
                  title: 'Gas Level',
                  lineColor: Colors.purple,
                  unit: 'ppm',
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedDevice: selectedDevice,
                  selectedSensor: selectedSensor,
                ),
                SensorLineChart(
                  title: 'Sound Level',
                  lineColor: Colors.green,
                  unit: 'dB',
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedDevice: selectedDevice,
                  selectedSensor: selectedSensor,
                ),
                SensorBarChart(
                  title: 'Flame Detection',
                  barColor: Colors.red,
                  unit: '',
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedDevice: selectedDevice,
                  selectedSensor: selectedSensor,
                ),
                SensorBarChart(
                  title: 'Vibration',
                  barColor: Colors.teal,
                  unit: '',
                  bgColor: bgColor,
                  textColor: textColor,
                  selectedTimeRange: selectedTimeRange,
                  selectedDevice: selectedDevice,
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

class SensorLineChart extends StatefulWidget {
  final String title;
  final Color lineColor;
  final String unit;
  final Color bgColor;
  final Color textColor;
  final String selectedTimeRange;
  final String selectedDevice;
  final String selectedSensor;

  const SensorLineChart({
    super.key,
    required this.title,
    required this.lineColor,
    required this.unit,
    required this.bgColor,
    required this.textColor,
    required this.selectedTimeRange,
    required this.selectedDevice,
    required this.selectedSensor,
  });

  @override
  State<SensorLineChart> createState() => _SensorLineChartState();
}

class _SensorLineChartState extends State<SensorLineChart> {
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
  void didUpdateWidget(covariant SensorLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If filter parameters changed, refresh data
    if (oldWidget.selectedTimeRange != widget.selectedTimeRange ||
        oldWidget.selectedDevice != widget.selectedDevice ||
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
    if (widget.selectedSensor != 'All' &&
        widget.selectedSensor.toLowerCase() != widget.title.toLowerCase()) {
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

    try {
      final supabase = Supabase.instance.client;

      // Calculate time range
      final startTime = _getStartTimeForRange(widget.selectedTimeRange);
      final startTimeStr = startTime.toIso8601String();

      // Build query based on filters
      var query = supabase
          .from('sensor_data')
          .select('timestamp, ${widget.title.toLowerCase().split(' ')[0]}')
          .gte('timestamp', startTimeStr)
          .order('timestamp', ascending: true);

      // Add device filter if needed (assuming device_id column exists)
      // if (widget.selectedDevice != 'All') {
      //   query = query.eq('device_id', widget.selectedDevice);
      // }

      final response = await query;

      final List data = response;
      final List<FlSpot> points = [];
      final Map<double, String> labels = {};

      for (int i = 0; i < data.length; i++) {
        final entry = data[i];
        final value = entry[widget.title.toLowerCase().split(' ')[0]] as num?;
        if (value != null) {
          points.add(FlSpot(i.toDouble(), value.toDouble()));

          final timestamp = DateTime.parse(entry['timestamp']);
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
      debugPrint('Error fetching sensor data: $e');
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
                        minY: 0,
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

class SensorBarChart extends StatefulWidget {
  final String title;
  final Color barColor;
  final String unit;
  final Color bgColor;
  final Color textColor;
  final String selectedTimeRange;
  final String selectedDevice;
  final String selectedSensor;

  const SensorBarChart({
    super.key,
    required this.title,
    required this.barColor,
    required this.unit,
    required this.bgColor,
    required this.textColor,
    required this.selectedTimeRange,
    required this.selectedDevice,
    required this.selectedSensor,
  });

  @override
  State<SensorBarChart> createState() => _SensorBarChartState();
}

class _SensorBarChartState extends State<SensorBarChart> {
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
  void didUpdateWidget(covariant SensorBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If filter parameters changed, refresh data
    if (oldWidget.selectedTimeRange != widget.selectedTimeRange ||
        oldWidget.selectedDevice != widget.selectedDevice ||
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
    if (widget.selectedSensor != 'All' &&
        widget.selectedSensor.toLowerCase() != widget.title.toLowerCase()) {
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

    try {
      final supabase = Supabase.instance.client;

      // Calculate time range
      final startTime = _getStartTimeForRange(widget.selectedTimeRange);
      final startTimeStr = startTime.toIso8601String();

      // Build query based on filters
      var query = supabase
          .from('sensor_data')
          .select('timestamp, ${widget.title.toLowerCase().split(' ')[0]}')
          .gte('timestamp', startTimeStr)
          .order('timestamp', ascending: true);

      // Add device filter if needed (assuming device_id column exists)
      // if (widget.selectedDevice != 'All') {
      //   query = query.eq('device_id', widget.selectedDevice);
      // }

      final response = await query;

      final List data = response;
      final List<FlSpot> points = [];
      final Map<double, String> labels = {};

      for (int i = 0; i < data.length; i++) {
        final entry = data[i];
        final value = entry[widget.title.toLowerCase().split(' ')[0]] as num?;
        if (value != null) {
          points.add(FlSpot(i.toDouble(), value.toDouble()));

          final timestamp = DateTime.parse(entry['timestamp']);
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
      debugPrint('Error fetching sensor data: $e');
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
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: dataPoints.length * 20.0,
                        child: BarChart(
                          BarChartData(
                            barGroups:
                                dataPoints
                                    .map(
                                      (e) => BarChartGroupData(
                                        x: e.x.toInt(),
                                        barRods: [
                                          BarChartRodData(
                                            toY: e.y,
                                            color: widget.barColor,
                                            width: 6,
                                            borderRadius: BorderRadius.zero,
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  interval: calculateInterval(dataPoints),
                                  getTitlesWidget: (value, _) {
                                    final label = xLabels[value.toDouble()];
                                    return Transform.rotate(
                                      angle: -1.57,
                                      child: Text(
                                        label ?? '',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: widget.textColor.withOpacity(
                                            0.6,
                                          ),
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
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: false),
                          ),
                        ),
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
