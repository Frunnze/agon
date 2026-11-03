final DateTime galleryNow = DateTime(2026, 10, 29, 14, 9, 40);

DateTime galleryToday(int hour, int minute, [int second = 0]) {
  return DateTime(
    galleryNow.year,
    galleryNow.month,
    galleryNow.day,
    hour,
    minute,
    second,
  );
}

DateTime galleryYesterday(int hour, int minute, [int second = 0]) {
  return DateTime(
    galleryNow.year,
    galleryNow.month,
    galleryNow.day - 1,
    hour,
    minute,
    second,
  );
}

DateTime galleryDaysAgo(int days) {
  return galleryNow.subtract(Duration(days: days));
}

DateTime galleryTwoDaysAgo(int hour, int minute, [int second = 0]) {
  return DateTime(
    galleryNow.year,
    galleryNow.month,
    galleryNow.day - 2,
    hour,
    minute,
    second,
  );
}
