.PHONY: all

all:
	rm -f Out.txt
	$(JAVAC) -processor org.checkerframework.checker.nullness.NullnessChecker -AprintErrorStack test/*.java > Out.txt 2>&1 || true
	diff -u Expected.txt Out.txt
