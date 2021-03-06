// Testcase for Issue 948:
// https://github.com/typetools/checker-framework/issues/948

import tests.nontopdefault.qual.*;

// Problem: @DefaultFor TypeUseLocation.RECEIVER is not applied to inner class constructor
// receivers. The inner class constructor receivers currently take on the default qualifier of
// the hierarchy. All other methods take on the default qualifier set by TypeUseLocation.RECEIVER.

// @skip-test

class NTDConstructorReceiverTest {
    // default method receiver is @NTDTop
    void DefaultMethodReceiver() {
        // this line produces a methodref.receiver.bound.invalid error, but it shouldn't if the
        // receiver for inner class constructors are properly applied
        Demand<InnerDefaultReceiver> constructorReference = InnerDefaultReceiver::new;

        // this line does not as the receiver is explicitly declared to be @NTDTop
        Demand<InnerExplicitReceiver> constructorReference2 = InnerExplicitReceiver::new;
    }

    class InnerDefaultReceiver {
        // takes on the default receiver for inner class constructor methods
        InnerDefaultReceiver(NTDConstructorReceiverTest NTDConstructorReceiverTest.this) {}
    }

    class InnerExplicitReceiver {
        // explicitly set the receiver to be @NTDTop
        InnerExplicitReceiver(@NTDTop NTDConstructorReceiverTest NTDConstructorReceiverTest.this) {}
    }
}

interface Demand<R> {
    R supply();
}
