package org.springframework.samples.petclinic;

import com.amazonaws.xray.spring.aop.XRayEnabled;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
class SlowController {
    @GetMapping("/test")
    public String test() {
        try {
            int random = (int) (Math.random() * 2000) + 3000;
            Thread.sleep(random);
        }catch (InterruptedException e) {
            // Do nothing
        }

        return "welcome";
    }
}
