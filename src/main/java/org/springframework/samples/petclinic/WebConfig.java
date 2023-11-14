package org.springframework.samples.petclinic;

import com.amazonaws.xray.AWSXRay;
import com.amazonaws.xray.AWSXRayRecorderBuilder;
import com.amazonaws.xray.javax.servlet.AWSXRayServletFilter;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
@EnableAutoConfiguration
@Profile("x-ray")
public class WebConfig {

    private static final String SERVICE = "Reinvent-demo";

    @Bean
    public AWSXRayServletFilter TracingFilter() {
        return new AWSXRayServletFilter(SERVICE);
    }

    // Enable Xray
    static {
        AWSXRayRecorderBuilder builder = AWSXRayRecorderBuilder.standard();
        AWSXRay.setGlobalRecorder(builder.build());
        AWSXRay.beginSegment(SERVICE);
    }
}
