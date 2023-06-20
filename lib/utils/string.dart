extension StringManipulation on String {
    String titleCase() {
        return toLowerCase().replaceAllMapped(
            RegExp(r'[A-Z]{2,}(?=[A-Z][a-z]+[0-9]*|\b)|[A-Z]?[a-z]+[0-9]*|[A-Z]|[0-9]+'),
            (match) => '${match[0]![0].toUpperCase()}${match[0]!.substring(1).toLowerCase()}'
        );
    }
}