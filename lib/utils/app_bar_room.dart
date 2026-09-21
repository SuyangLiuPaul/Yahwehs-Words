import 'package:flutter/widgets.dart';

/// How wide a screen has to be before a sub-page's app bar can afford
/// its two conveniences — Home and the language menu — as well as the
/// things the page itself needs.
///
/// 2026-09-21, from a photo of an older reader's phone: the search
/// page's field was a thumb's width, squeezed between back, help,
/// filter, language and home. 「是不是太小的时候右边有些可以调整一下呢
/// 或者去掉 因为返回home有些重复 语言调整不一定有需要 … 大一点显示无所谓
/// 但是太小了就不用了」.
///
/// That phone was an iPhone in Display Zoom, which reports 320 wide.
/// Measured on the pushed search page at that width, the field was
/// 36 px with both conveniences on the bar and is 132 px without them
/// (`test/search_field_reachable_test.dart`). 380 is the line because it keeps
/// both on every standard-size iPhone (390 and up) and drops them on
/// the ones that are genuinely tight: Display Zoom (320 / 375), the SE
/// and mini (375), and the 360-wide Androids.
///
/// Why these two and nothing else: each is available somewhere the
/// reader cannot miss. Home is one tap of Back away on a sub-page, and
/// the language is in Settings and on the home page's own bar. Every
/// other action on a page's bar is that page's own job.
const double kRoomyAppBarWidth = 380;

/// True when [context]'s screen is too narrow for a sub-page's bar to
/// carry Home and the language menu. See [kRoomyAppBarWidth].
bool appBarIsCramped(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kRoomyAppBarWidth;
