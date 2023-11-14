package org.springframework.samples.petclinic;

import com.amazonaws.xray.AWSXRay;
import com.amazonaws.xray.entities.Segment;
import com.amazonaws.xray.spring.aop.AbstractXRayInterceptor;

import javax.servlet.http.HttpServletRequest;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Pointcut;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

@Aspect
@Component
@Profile("x-ray")
public class XRayInspector extends AbstractXRayInterceptor {

    private static final String SESSION_ID = "SessionId";
    private static final String ARGS = "Args";

    @Override
    @Pointcut("@within(com.amazonaws.xray.spring.aop.XRayEnabled)")
    public void xrayEnabledClasses() {
    }

    /**
     * Customize, annotations and data sent to X-ray
     */
    @Override
    public Object traceAroundMethods(ProceedingJoinPoint pjp) throws Throwable {
        Segment segment = AWSXRay.getCurrentSegment();
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        if (attributes != null) {
            HttpServletRequest request = attributes.getRequest();
            Map<String, Object> annotationMap = new HashMap<>();

            // Pass input args and session ID part of segment annotation
            if (pjp.getArgs() != null) {
                Optional<String> args = Arrays.stream(pjp.getArgs())
                        .filter(Objects::nonNull)
                        .map(Object::toString)
                        .reduce((a, b) -> a + ", " + b);
                args.ifPresent(s -> annotationMap.put(ARGS, s));
            }

            annotationMap.put(SESSION_ID, request.getSession().getId());
            segment.setAnnotations(annotationMap);
        }

        return super.traceAroundMethods(pjp);
    }

    // Customize behavior around spring data repository
    @Override
    public Object traceAroundRepositoryMethods(ProceedingJoinPoint pjp) throws Throwable {
        return super.traceAroundRepositoryMethods(pjp);
    }
}
