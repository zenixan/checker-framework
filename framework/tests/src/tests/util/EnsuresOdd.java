package tests.util;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.checkerframework.framework.qual.InheritedAnnotation;
import org.checkerframework.framework.qual.PostconditionAnnotation;

/**
 * A postcondition annotation to indicate that a method ensures certain expressions to be {@link
 * Odd}.
 *
 * @author Stefan Heule
 */
@PostconditionAnnotation(qualifier = Odd.class)
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target({ElementType.METHOD, ElementType.CONSTRUCTOR})
@InheritedAnnotation
public @interface EnsuresOdd {
    String[] value();
}
