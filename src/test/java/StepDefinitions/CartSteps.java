package StepDefinitions;

import com.pages.bsHome;
import io.cucumber.java.Before;
import io.cucumber.java.Scenario;
import io.cucumber.java.en.Then;
import io.cucumber.java.en.When;
import org.testng.Assert;

public class CartSteps {
    ApplicationHooks hooks;
    private final bsHome bshome;

    public CartSteps(ApplicationHooks hooks) {
        this.hooks = hooks;
        bshome = new bsHome(hooks.driver);
    }

    Scenario sc;

    @Before
    public void getScenario(Scenario scenario) {
        this.sc = scenario;
    }

    @When("User clicks on {string} Add To Cart button {int} times")
    public void user_clicks_on_add_to_cart(String deviceName, int clicks) {
        bshome.addToCartNTimes(deviceName, clicks);
    }

    @Then("The cart gets updated with {string} and {int}")
    public void cart_is_updated(String deviceName, int quantity) {
        sc.log("Starting cart verification");
        System.out.println("Starting cart verification");
        boolean cartUpdated = bshome.verifyCart(deviceName, quantity);
        if (cartUpdated) {
            System.out.println("Cart updated with correct details");
            sc.log("Cart updated with correct details");
        } else {
            throw new AssertionError("Cart not updated correctly");
        }
    }

}