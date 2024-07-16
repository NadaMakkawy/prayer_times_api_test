import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:arabic_numbers/arabic_numbers.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

final prayerTimesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  const baseUrl = 'http://api.aladhan.com/v1';

  final response = await http.get(
    Uri.parse(
      '$baseUrl/timingsByAddress?address=Nasr City, Cairo, EG',
    ),
  );

  final data = jsonDecode(response.body);
  final timings = data['data']['timings'];

  final prayerTimes = [
    {
      'name': 'الفجر',
      'time': formatTime(timings['Fajr']),
      'dateTime': getDateTime(timings['Fajr']),
      'duration': calculateDuration(timings['Fajr'], timings['Sunrise']),
      'background': Colors.indigo.shade200,
    },
    {
      'name': 'الشروق',
      'time': formatTime(timings['Sunrise']),
      'dateTime': getDateTime(timings['Sunrise']),
      'duration': calculateDuration(timings['Sunrise'], timings['Dhuhr']),
      'background': Colors.amber.shade100,
    },
    {
      'name': 'الظهر',
      'time': formatTime(timings['Dhuhr']),
      'dateTime': getDateTime(timings['Dhuhr']),
      'duration': calculateDuration(timings['Dhuhr'], timings['Asr']),
      'background': Colors.cyan.shade200,
    },
    {
      'name': 'العصر',
      'time': formatTime(timings['Asr']),
      'dateTime': getDateTime(timings['Asr']),
      'duration': calculateDuration(timings['Asr'], timings['Maghrib']),
      'background': Colors.blue.shade100,
    },
    {
      'name': 'المغرب',
      'time': formatTime(timings['Maghrib']),
      'dateTime': getDateTime(timings['Maghrib']),
      'duration': calculateDuration(timings['Maghrib'], timings['Isha']),
      'background': Colors.orange.shade200,
    },
    {
      'name': 'العشاء',
      'time': formatTime(timings['Isha']),
      'dateTime': getDateTime(timings['Isha']),
      'duration': calculateDuration(timings['Isha'], timings['Fajr']),
      'background': Colors.grey.shade400,
    },
  ];

  return prayerTimes;
});

int nextPrayerIndex = 0;

DateTime getDateTime(String time) {
  final now = DateTime.now();
  final parts = time.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  return DateTime(now.year, now.month, now.day, hour, minute);
}

Duration calculateRemainingTime(DateTime prayerTime, int index) {
  final now = DateTime.now();
  final remainingTime = prayerTime.difference(now);

  if (remainingTime.isNegative) {
    return remainingTime;
  }

  nextPrayerIndex = index;

  return remainingTime;
}

String formatTime(String time) {
  final parts = time.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  final formatter = DateFormat('h:mm a', 'ar');
  final formattedTime = formatter.format(
    DateTime(0, 1, 1, hour, minute),
  );

  return formattedTime;
}

Duration calculateDuration(String startTime, String endTime) {
  final startParts = startTime.split(':');
  final endParts = endTime.split(':');
  final startHour = int.parse(startParts[0]);
  final startMinute = int.parse(startParts[1]);
  final endHour = int.parse(endParts[0]);
  final endMinute = int.parse(endParts[1]);

  final startDateTime = DateTime(0, 1, 1, startHour, startMinute);
  final endDateTime = DateTime(0, 1, 1, endHour, endMinute);

  return endDateTime.difference(startDateTime).abs();
}

class MainAppScreen extends ConsumerStatefulWidget {
  const MainAppScreen({super.key});

  @override
  _MainAppScreenState createState() => _MainAppScreenState();
}

class _MainAppScreenState extends ConsumerState<MainAppScreen> {
  final arabicNumber = ArabicNumbers();
  Timer? _timer;
  int nextPrayerIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Widget build(BuildContext context) {
    initializeDateFormatting('ar', null);
    final prayerTimesAsyncValue = ref.watch(prayerTimesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              stretch: true,
              title: const Center(
                child: Text.rich(
                  TextSpan(
                    text: 'Prayer',
                    style: TextStyle(
                      fontSize: 28,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: 'Times',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: AnimatedContainer(
                  duration: const Duration(seconds: 1),
                  color: prayerTimesAsyncValue.when(
                    data: backgroundColorMethod,
                    loading: () => Colors.white,
                    error: (_, __) => Colors.transparent,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  prayerTimesAsyncValue.when(
                    data: getPercent,
                    loading: () => const CircularProgress(),
                    error: (error, stackTrace) => Text('Error: $error'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget getPercent(prayerTimes) {
    final currentPrayer = prayerTimes[nextPrayerIndex];
    final prayerDateTime = currentPrayer['dateTime'];
    Duration remainingTime =
        calculateRemainingTime(prayerDateTime, nextPrayerIndex);
    double percent =
        remainingTime.inSeconds / currentPrayer['duration'].inSeconds;
    percent = percent.clamp(0.0, 1.0);

    if (remainingTime.inMinutes > -5) {
      return AnimatedSwitcher(
        duration: const Duration(seconds: 1),
        child: prayerIndicator(
          remainingTime,
          currentPrayer,
          percent,
          prayerTimes,
        ),
      );
    } else {
      if (nextPrayerIndex == prayerTimes.length - 1) {
        return prayerIndicator(
          remainingTime,
          currentPrayer,
          percent,
          prayerTimes,
        );
      }

      getNextPrayerIndex(prayerTimes);
      final nextPrayer = prayerTimes[nextPrayerIndex];
      final nextPrayerDateTime = nextPrayer['dateTime'];
      getRemaining(remainingTime, nextPrayerDateTime);
    }

    return const AnimatedSwitcher(
      duration: Duration(seconds: 1),
      child: AnimatedOpacity(
        opacity: 0.0,
        duration: Duration(seconds: 1),
        child: CircularProgress(),
      ),
    );
  }

  Color backgroundColorMethod(prayerTimes) {
    final currentPrayer = prayerTimes[nextPrayerIndex];
    final prayerDateTime = currentPrayer['dateTime'];
    Duration remainingTime =
        calculateRemainingTime(prayerDateTime, nextPrayerIndex);
    double percent =
        remainingTime.inSeconds / currentPrayer['duration'].inSeconds;
    percent = percent.clamp(0.0, 1.0);

    final backgroundColor = currentPrayer['background'];

    if (remainingTime.inMinutes > -5) {
      return backgroundColor;
    } else {
      if (nextPrayerIndex == prayerTimes.length - 1) {
        return backgroundColor;
      }
      getNextPrayerIndex(prayerTimes);
      final nextPrayer = prayerTimes[nextPrayerIndex];
      final nextPrayerDateTime = nextPrayer['dateTime'];
      getRemaining(remainingTime, nextPrayerDateTime);

      return nextPrayer['background'];
    }
  }

  Duration getRemaining(Duration remainingTime, nextPrayerDateTime) {
    return remainingTime =
        calculateRemainingTime(nextPrayerDateTime, nextPrayerIndex);
  }

  int getNextPrayerIndex(List<Map<String, dynamic>> prayerTimes) {
    return nextPrayerIndex = (nextPrayerIndex + 1) % prayerTimes.length;
  }

  Widget prayerIndicator(
    Duration remainingTime,
    Map<String, dynamic> currentPrayer,
    double percent,
    List<Map<String, dynamic>> prayerTimes,
  ) {
    final Color backgroundColor = currentPrayer['background'];

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(seconds: 1),
      child: AnimatedContainer(
        height: MediaQuery.of(context).size.height,
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          color: backgroundColor,
        ),
        child: Column(
          children: [
            const SizedBox(
              height: 30,
            ),
            RemainingText(
              nextPrayerIndex: nextPrayerIndex,
              remainingTime: remainingTime,
              currentPrayer: currentPrayer,
            ),
            const SizedBox(
              height: 30,
            ),
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.6,
                child: Indicator(
                  arabicNumber: arabicNumber,
                  percent: percent,
                  remainingTime: remainingTime,
                ),
              ),
            ),
            buildPrayerList(prayerTimes),
          ],
        ),
      ),
    );
  }
}

class CircularProgress extends StatelessWidget {
  const CircularProgress({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: const Center(
        child: CircularProgressIndicator(
          backgroundColor: Colors.amber,
        ),
      ),
    );
  }
}

class RemainingText extends StatelessWidget {
  const RemainingText({
    super.key,
    required this.nextPrayerIndex,
    required this.remainingTime,
    required this.currentPrayer,
  });

  final int nextPrayerIndex;
  final Duration remainingTime;
  final Map<String, dynamic> currentPrayer;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${remainingTime.isNegative ? 'مضى' : 'باقي'} على ${nextPrayerIndex == 1 ? currentPrayer['name'] : 'أذان ${currentPrayer['name']}'}',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 28,
      ),
    );
  }
}

class Indicator extends StatelessWidget {
  const Indicator({
    super.key,
    required this.arabicNumber,
    required this.percent,
    required this.remainingTime,
  });

  final ArabicNumbers arabicNumber;
  final double percent;
  final Duration remainingTime;

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      enableLoadingAnimation: true,
      animationDuration: 500,
      axes: <RadialAxis>[
        RadialAxis(
          startAngle: 180,
          endAngle: 0,
          showLabels: false,
          showTicks: false,
          axisLineStyle: const AxisLineStyle(
            thickness: 30,
            gradient: SweepGradient(
              center: FractionalOffset.center,
              colors: <Color>[
                Colors.blue,
                Colors.blueAccent,
              ],
              stops: <double>[0.5, 0.5],
            ),
          ),
          pointers: <GaugePointer>[
            RangePointer(
              value: percent * 100,
              gradient: const SweepGradient(
                center: FractionalOffset.center,
                colors: <Color>[
                  Colors.green,
                  Colors.green,
                  Colors.green,
                  Colors.lightGreen,
                  Colors.lightGreen,
                ],
                stops: <double>[0.0, 0.25, 0.5, 0.75, 1.0],
              ),
              pointerOffset: 0,
              cornerStyle: percent * 100 <= 98
                  ? CornerStyle.endCurve
                  : CornerStyle.bothFlat,
              width: 30,
              sizeUnit: GaugeSizeUnit.logicalPixel,
            ),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: RemainingTimeText(
                arabicNumber: arabicNumber,
                remainingTime: remainingTime,
              ),
              angle: 90,
              positionFactor: 0,
            ),
          ],
        ),
      ],
    );
  }
}

class RemainingTimeText extends StatelessWidget {
  const RemainingTimeText({
    super.key,
    required this.arabicNumber,
    required this.remainingTime,
  });

  final ArabicNumbers arabicNumber;
  final Duration remainingTime;

  @override
  Widget build(BuildContext context) {
    return Text(
      arabicNumber.convert(
          '${remainingTime.inSeconds.remainder(60).abs().toString().padLeft(2, '0')} : ${remainingTime.inMinutes.remainder(60).abs().toString().padLeft(2, '0')} : ${remainingTime.inHours.abs().toString().padLeft(2, '0')}'),
      style: const TextStyle(
        fontSize: 50,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

Widget buildPrayerList(
  List<Map<String, dynamic>> prayerTimes,
) {
  return ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    padding: const EdgeInsets.only(
      left: 8,
      right: 8,
      bottom: 20,
    ),
    itemCount: prayerTimes.length,
    itemBuilder: (BuildContext context, int index) {
      final prayer = prayerTimes[index];
      final prayerName = prayer['name'];
      final prayerTime = prayer['time'];
      final prayerDateTime = prayer['dateTime'];
      final remainingTime = calculateRemainingTime(prayerDateTime, index);
      double percent = remainingTime.inSeconds / prayer['duration'].inSeconds;
      percent = percent.clamp(0.0, 1.0);

      return Column(
        children: [
          PrayerItem(
            prayerName: prayerName,
            prayerTime: prayerTime,
            percent: percent,
          ),
          const Divider(
            color: Colors.green,
            indent: 20,
            endIndent: 20,
          ),
        ],
      );
    },
  );
}

class PrayerItem extends StatelessWidget {
  const PrayerItem({
    super.key,
    required this.prayerName,
    required this.prayerTime,
    required this.percent,
  });

  final String prayerName;
  final String prayerTime;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final isCurrentPrayer = percent * 100 == 0;

    return ListTile(
      trailing: PrayerText(
        text: prayerName,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 25,
          color: isCurrentPrayer ? Colors.red : Colors.black,
        ),
      ),
      leading: PrayerText(
        text: prayerTime,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 25,
          color: isCurrentPrayer ? Colors.red : Colors.black,
        ),
      ),
    );
  }
}

class PrayerText extends StatelessWidget {
  const PrayerText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
    );
  }
}
