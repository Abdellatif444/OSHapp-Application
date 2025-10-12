// package com.oshapp.backend.integration;

// import com.fasterxml.jackson.databind.ObjectMapper;
// import com.oshapp.backend.dto.LoginRequest;
// import com.oshapp.backend.model.ActivationToken;
// import com.oshapp.backend.model.Role;
// import com.oshapp.backend.model.User;
// import com.oshapp.backend.model.enums.RoleName;
// import com.oshapp.backend.repository.ActivationTokenRepository;
// import com.oshapp.backend.repository.RoleRepository;
// import com.oshapp.backend.repository.UserRepository;
// import com.oshapp.backend.service.EmailService;
// import com.oshapp.backend.service.UserService;
// import org.junit.jupiter.api.BeforeEach;
// import org.junit.jupiter.api.DisplayName;
// import org.junit.jupiter.api.Test;
// import org.mockito.ArgumentCaptor;
// import org.springframework.beans.factory.annotation.Autowired;
// import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
// import org.springframework.boot.test.context.SpringBootTest;
// import org.springframework.boot.test.mock.mockito.MockBean;
// import org.springframework.http.MediaType;
// import org.springframework.security.crypto.password.PasswordEncoder;
// import org.springframework.test.web.servlet.MockMvc;
// import org.springframework.transaction.annotation.Transactional;

// import java.time.LocalDateTime;
// import java.util.Map;
// import java.util.Set;

// import static org.assertj.core.api.Assertions.assertThat;
// import static org.mockito.ArgumentMatchers.anyString;
// import static org.mockito.ArgumentMatchers.eq;
// import static org.mockito.Mockito.never;
// import static org.mockito.Mockito.times;
// import static org.mockito.Mockito.verify;
// import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
// import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
// import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

// @SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
// @AutoConfigureMockMvc
// @Transactional
// public class AccountActivationAuthIT {

//     @Autowired
//     private MockMvc mockMvc;

//     @Autowired
//     private ObjectMapper objectMapper;

//     @Autowired
//     private UserRepository userRepository;

//     @Autowired
//     private RoleRepository roleRepository;

//     @Autowired
//     private ActivationTokenRepository activationTokenRepository;

//     @Autowired
//     private PasswordEncoder passwordEncoder;

//     @Autowired
//     private UserService userService;

//     @MockBean
//     private EmailService emailService;

//     @BeforeEach
//     void setUp() {
//         activationTokenRepository.deleteAll();
//         userRepository.deleteAll();
//         roleRepository.deleteAll();
//         roleRepository.save(new Role(RoleName.ROLE_EMPLOYEE));
//         roleRepository.save(new Role(RoleName.ROLE_ADMIN));
//     }

//     private User createUser(String email, boolean enabled, Set<Role> roles) {
//         User u = new User();
//         u.setEmail(email);
//         u.setUsername(email);
//         u.setPassword(passwordEncoder.encode("password"));
//         u.setRoles(roles);
//         u.setActive(true);
//         u.setEnabled(enabled);
//         return userRepository.save(u);
//     }

//     private Set<Role> employeeRoles() {
//         return Set.of(roleRepository.findByName(RoleName.ROLE_EMPLOYEE).orElseThrow());
//     }

//     private Set<Role> adminRoles() {
//         return Set.of(roleRepository.findByName(RoleName.ROLE_ADMIN).orElseThrow());
//     }

//     @Test
//     @DisplayName("Activate account with valid token enables user and deletes token")
//     void activateAccount_withValidToken_shouldEnableUserAndDeleteToken() throws Exception {
//         User user = createUser("user1@oshapp.com", false, employeeRoles());

//         // Generate activation token
//         userService.createAndSendActivationToken(user);

//         // Fetch the generated token for this user
//         ActivationToken tokenEntity = activationTokenRepository.findAll().stream()
//                 .filter(t -> t.getUser().getId().equals(user.getId()))
//                 .findFirst().orElseThrow();
//         String token = tokenEntity.getToken();

//         // Call activation endpoint
//         mockMvc.perform(post("/api/v1/account/activate")
//                         .contentType(MediaType.APPLICATION_JSON)
//                         .content(objectMapper.writeValueAsString(Map.of("token", token))))
//                 .andExpect(status().isOk());

//         // Assert user enabled and token deleted
//         User reloaded = userRepository.findByUsernameOrEmail(user.getEmail(), user.getEmail()).orElseThrow();
//         assertThat(reloaded.isEnabled()).isTrue();
//         assertThat(activationTokenRepository.findByToken(token)).isEmpty();
//     }

//     @Test
//     @DisplayName("Activate account with expired token returns 400, sends new token, and keeps user disabled")
//     void activateAccount_withExpiredToken_shouldReturnBadRequestAndSendNewToken() throws Exception {
//         User user = createUser("user2@oshapp.com", false, employeeRoles());

//         // Manually create an expired token
//         ActivationToken old = new ActivationToken();
//         old.setUser(user);
//         old.setToken("111111");
//         old.setExpiresAt(LocalDateTime.now().minusMinutes(1));
//         activationTokenRepository.save(old);

//         // Attempt activation with expired token
//         mockMvc.perform(post("/api/v1/account/activate")
//                         .contentType(MediaType.APPLICATION_JSON)
//                         .content(objectMapper.writeValueAsString(Map.of("token", "111111"))))
//                 .andExpect(status().isBadRequest());

//         // Old token deleted
//         assertThat(activationTokenRepository.findByToken("111111")).isEmpty();

//         // New token generated for user
//         ActivationToken newToken = activationTokenRepository.findAll().stream()
//                 .filter(t -> t.getUser().getId().equals(user.getId()))
//                 .findFirst().orElse(null);
//         assertThat(newToken).isNotNull();
//         assertThat(newToken.getToken()).isNotEqualTo("111111");

//         // Email sent with new token
//         ArgumentCaptor<String> tokenCaptor = ArgumentCaptor.forClass(String.class);
//         verify(emailService, times(1)).sendActivationEmail(eq(user), tokenCaptor.capture());
//         assertThat(tokenCaptor.getValue()).hasSize(6);

//         // User remains disabled
//         User reloaded = userRepository.findByUsernameOrEmail(user.getEmail(), user.getEmail()).orElseThrow();
//         assertThat(reloaded.isEnabled()).isFalse();
//     }

//     @Test
//     @DisplayName("Resend activation code for non-enabled user returns 200 and sends email")
//     void resendActivation_forNotEnabledUser_shouldSendToken() throws Exception {
//         User user = createUser("user3@oshapp.com", false, employeeRoles());

//         mockMvc.perform(post("/api/v1/account/resend-activation")
//                         .contentType(MediaType.APPLICATION_JSON)
//                         .content(objectMapper.writeValueAsString(Map.of("email", user.getEmail()))))
//                 .andExpect(status().isOk());

//         // Token created
//         ActivationToken token = activationTokenRepository.findAll().stream()
//                 .filter(t -> t.getUser().getId().equals(user.getId()))
//                 .findFirst().orElse(null);
//         assertThat(token).isNotNull();

//         // Email sent
//         verify(emailService, times(1)).sendActivationEmail(eq(user), anyString());
//     }

//     @Test
//     @DisplayName("Resend activation code for enabled user returns 409 and does not send email")
//     void resendActivation_forEnabledUser_shouldReturnConflict() throws Exception {
//         User user = createUser("user4@oshapp.com", true, employeeRoles());

//         mockMvc.perform(post("/api/v1/account/resend-activation")
//                         .contentType(MediaType.APPLICATION_JSON)
//                         .content(objectMapper.writeValueAsString(Map.of("email", user.getEmail()))))
//                 .andExpect(status().isConflict());

//         verify(emailService, never()).sendActivationEmail(eq(user), anyString());
//     }

//     @Test
//     @DisplayName("Login with non-activated user returns 403 ACCOUNT_NOT_ACTIVATED and triggers activation email")
//     void login_nonActivatedUser_shouldReturnForbiddenAndSendToken() throws Exception {
//         User user = createUser("user5@oshapp.com", false, employeeRoles());

//         LoginRequest loginRequest = new LoginRequest(user.getEmail(), "password");
//         mockMvc.perform(post("/api/v1/auth/login")
//                         .contentType(MediaType.APPLICATION_JSON)
//                         .content(objectMapper.writeValueAsString(loginRequest)))
//                 .andExpect(status().isForbidden())
//                 .andExpect(jsonPath("$.error").value("ACCOUNT_NOT_ACTIVATED"));

//         // Token created and email sent
//         ActivationToken token = activationTokenRepository.findAll().stream()
//                 .filter(t -> t.getUser().getId().equals(user.getId()))
//                 .findFirst().orElse(null);
//         assertThat(token).isNotNull();
//         verify(emailService, times(1)).sendActivationEmail(eq(user), anyString());
//     }

//     @Test
//     @DisplayName("Login with activated user succeeds and returns JWT token")
//     void login_activatedUser_shouldSucceed() throws Exception {
//         User user = createUser("user6@oshapp.com", true, employeeRoles());

//         LoginRequest loginRequest = new LoginRequest(user.getEmail(), "password");
//         mockMvc.perform(post("/api/v1/auth/login")
//                         .contentType(MediaType.APPLICATION_JSON)
//                         .content(objectMapper.writeValueAsString(loginRequest)))
//                 .andExpect(status().isOk())
//                 .andExpect(jsonPath("$.token").exists());
//     }

//     @Test
//     @DisplayName("Activate account with non-existing token returns 400")
//     void activateAccount_withInvalidToken_shouldReturnBadRequest() throws Exception {
//         mockMvc.perform(post("/api/v1/account/activate")
//                         .contentType(MediaType.APPLICATION_JSON)
//                         .content(objectMapper.writeValueAsString(Map.of("token", "999999"))))
//                 .andExpect(status().isBadRequest());
//     }
// }
