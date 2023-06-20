import 'package:intl/intl.dart';

extension DateFormatting on DateTime {
    String inString(){
        DateTime now = DateTime.now();
        String date = DateFormat.yMMMMd().format(this);

        if (hour + minute != 0){
            date = DateFormat.yMMMMd().add_Hm().format(this);
            if (year + month + day == now.year + now.month + now.day) {
                date = DateFormat.Hm().format(this);
            }
        }

        return date;
    }

    String inDateString(){
        return DateFormat.yMMMMd().format(this);
    }

    String inTimeString(){
        return DateFormat.Hm().format(this);
    }

    String inDateTimeString(){
        return DateFormat.yMMMMd().add_Hm().format(this);
    }
}