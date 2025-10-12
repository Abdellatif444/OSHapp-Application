package com.oshapp.backend.integration;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.Role;
import com.oshapp.backend.model.User;
import com.oshapp.backend.dto.AppointmentRequestDTO;
import com.oshapp.backend.dto.AppointmentCommentRequestDTO;
import com.oshapp.backend.dto.CancelRequestDTO;
import com.oshapp.backend.dto.LoginRequest;
import com.oshapp.backend.dto.ProposeSlotRequestDTO;
import com.oshapp.backend.model.enums.AppointmentType;
import com.oshapp.backend.model.enums.AppointmentStatus;
import com.oshapp.backend.model.enums.RoleName;
import com.oshapp.backend.model.enums.VisitMode;
import com.oshapp.backend.model.enums.NotificationType;
import com.oshapp.backend.repository.EmployeeRepository;
import com.oshapp.backend.repository.RoleRepository;
import com.oshapp.backend.repository.UserRepository;
import com.oshapp.backend.service.MultiChannelNotificationService;
import com.oshapp.backend.service.NotificationService;
import com.oshapp.backend.service.EmailService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Set;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
@Transactional
public class AppointmentFlowIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private EmployeeRepository employeeRepository;

    @Autowired
    private RoleRepository roleRepository;

    @SpyBean
    private MultiChannelNotificationService multiNotifService;

    @MockBean
    private NotificationService inAppNotificationService;

    @MockBean
    private EmailService emailService;

    @BeforeEach
    public void setUp() {
        // Ensure roles exist idempotently to avoid unique constraint violations across runs
        ensureRole(RoleName.ROLE_EMPLOYEE);
        ensureRole(RoleName.ROLE_NURSE);
        ensureRole(RoleName.ROLE_RH);
        ensureRole(RoleName.ROLE_ADMIN);
        ensureRole(RoleName.ROLE_DOCTOR);

        // Generate a unique suffix to avoid email/username collisions across runs without DB cleanup
        this.uniqueSuffix = String.valueOf(System.nanoTime());
    }

    @Autowired
    private PasswordEncoder passwordEncoder;

    private User employeeUser, manager1User, manager2User, nurseUser, rhUser, adminUser;
    private String uniqueSuffix;

    @Test
    @DisplayName("Employee Initiated Appointment should trigger notifications for all actors")
    @SuppressWarnings("unchecked") // Suppress warning for ArgumentCaptor with generic Set
    public void testEmployeeInitiatedAppointmentFlow() throws Exception {
        // 1. Setup test data
        setUpTestUsersAndEmployees();

        // 2. Authenticate as Employee to get JWT token
        LoginRequest loginRequest = new LoginRequest(employeeUser.getEmail(), "password");
        String responseString = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        String token = objectMapper.readTree(responseString).get("token").asText();

        // 3. Employee requests an appointment
        AppointmentRequestDTO requestDTO = new AppointmentRequestDTO();
        requestDTO.setRequestedDateEmployee(LocalDateTime.now().plusDays(5));
        requestDTO.setReason("Test Reason");
        requestDTO.setType(AppointmentType.SPONTANEOUS);

        mockMvc.perform(post("/api/v1/appointments/Rendez-vous-spontanee")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestDTO)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.REQUESTED_EMPLOYEE.toString()));

        // 4. Verify notifications are sent to all relevant actors for APPOINTMENT_REQUESTED
        ArgumentCaptor<java.util.List<User>> usersCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(usersCaptor.capture(), any(), eq("APPOINTMENT_REQUESTED"), any());

        Set<String> notifiedUserEmails = usersCaptor.getValue().stream().map(User::getEmail).collect(Collectors.toSet());

        // Allow additional seeded users (e.g., globally seeded nurses/doctors/RH) by checking inclusion only
        assertThat(notifiedUserEmails).contains(
                employeeUser.getEmail(),
                manager1User.getEmail(),
                manager2User.getEmail(),
                rhUser.getEmail(),
                nurseUser.getEmail()
        );

        // Assert in-app notification messages content for APPOINTMENT_REQUESTED
        ArgumentCaptor<User> uCap = ArgumentCaptor.forClass(User.class);
        ArgumentCaptor<String> titleCap = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> msgCap = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<NotificationType> typeCap = ArgumentCaptor.forClass(NotificationType.class);
        ArgumentCaptor<String> urlCap = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> relTypeCap = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Long> relIdCap = ArgumentCaptor.forClass(Long.class);

        verify(inAppNotificationService, atLeastOnce()).sendGeneralNotification(
                uCap.capture(), titleCap.capture(), msgCap.capture(), typeCap.capture(), urlCap.capture(), relTypeCap.capture(), relIdCap.capture());

        java.util.List<User> uVals = uCap.getAllValues();
        java.util.List<String> tVals = titleCap.getAllValues();
        java.util.List<String> mVals = msgCap.getAllValues();

        String rhMsg = null;
        String nurseMsg = null;
        for (int i = 0; i < uVals.size(); i++) {
            if ("Nouvelle demande de rendez-vous".equals(tVals.get(i))) {
                if (uVals.get(i).getEmail().equals(rhUser.getEmail())) {
                    rhMsg = mVals.get(i);
                }
                if (uVals.get(i).getEmail().equals(nurseUser.getEmail())) {
                    nurseMsg = mVals.get(i);
                }
            }
        }
        assertThat(rhMsg).isNotNull();
        assertThat(rhMsg).contains("(" + employeeUser.getEmail() + ")"); // RH sees email, privacy-preserving format
        assertThat(nurseMsg).isNotNull();
        assertThat(nurseMsg).contains("Nouvelle demande de rendez-vous :");
        assertThat(nurseMsg).doesNotContain("(" + employeeUser.getEmail() + ")"); // Non-RH shouldn't see email here
    }

    private void setUpTestUsersAndEmployees() {
        Role employeeRole = roleRepository.findByName(RoleName.ROLE_EMPLOYEE).get();
        Role nurseRole = roleRepository.findByName(RoleName.ROLE_NURSE).get();
        Role rhRole = roleRepository.findByName(RoleName.ROLE_RH).get();
        Role adminRole = roleRepository.findByName(RoleName.ROLE_ADMIN).get();

        adminUser = createTestUser(uniqueEmail("admin"), Set.of(adminRole));
        createTestEmployee(adminUser, "Admin", "User", null, null);

        rhUser = createTestUser(uniqueEmail("rh"), Set.of(rhRole));
        createTestEmployee(rhUser, "RH", "User", null, null);

        nurseUser = createTestUser(uniqueEmail("nurse"), Set.of(nurseRole));
        createTestEmployee(nurseUser, "Nurse", "User", null, null);

        manager2User = createTestUser(uniqueEmail("manager2"), Set.of(employeeRole));
        Employee manager2 = createTestEmployee(manager2User, "Manager", "Two", null, null);

        manager1User = createTestUser(uniqueEmail("manager1"), Set.of(employeeRole));
        Employee manager1 = createTestEmployee(manager1User, "Manager", "One", manager2, null);

        employeeUser = createTestUser(uniqueEmail("employee"), Set.of(employeeRole));
        createTestEmployee(employeeUser, "Employee", "User", manager1, manager2);
    }

    private User createTestUser(String email, Set<Role> roles) {
        User user = new User();
        user.setEmail(email);
        user.setUsername(email);
        user.setPassword(passwordEncoder.encode("password"));
        user.setRoles(roles);
        user.setActive(true);
        user.setEnabled(true);
        return userRepository.save(user);
    }

    private Role ensureRole(RoleName roleName) {
        return roleRepository.findByName(roleName)
                .orElseGet(() -> roleRepository.save(new Role(roleName)));
    }

    private String uniqueEmail(String localPart) {
        return localPart + "+it" + uniqueSuffix + "@oshapp.com";
    }

    private Employee createTestEmployee(User user, String firstName, String lastName, Employee manager1, Employee manager2) {
        Employee employee = new Employee();
        employee.setUser(user);
        employee.setFirstName(firstName);
        employee.setLastName(lastName);
        employee.setManager1(manager1);
        employee.setManager2(manager2);
        return employeeRepository.save(employee);
    }

    @Test
    @DisplayName("Nurse proposes a slot -> status PROPOSED_MEDECIN and notifications sent")
    public void testNurseProposalFlow() throws Exception {
        // 1. Setup users and employees
        setUpTestUsersAndEmployees();

        // 2. Authenticate as Employee and create a requested appointment
        LoginRequest employeeLogin = new LoginRequest(employeeUser.getEmail(), "password");
        String employeeLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(employeeLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String employeeToken = objectMapper.readTree(employeeLoginResponse).get("token").asText();

        AppointmentRequestDTO requestDTO = new AppointmentRequestDTO();
        requestDTO.setRequestedDateEmployee(LocalDateTime.now().plusDays(3));
        requestDTO.setType(AppointmentType.SPONTANEOUS);

        MvcResult createResult = mockMvc.perform(post("/api/v1/appointments/Rendez-vous-spontanee")
                        .header("Authorization", "Bearer " + employeeToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestDTO)))
                .andExpect(status().isCreated())
                .andReturn();
        JsonNode created = objectMapper.readTree(createResult.getResponse().getContentAsString());
        Long appointmentId = created.get("id").asLong();

        // 3. Authenticate as Nurse
        LoginRequest nurseLogin = new LoginRequest(nurseUser.getEmail(), "password");
        String nurseLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(nurseLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String nurseToken = objectMapper.readTree(nurseLoginResponse).get("token").asText();

        // 4. Nurse proposes a new slot
        ProposeSlotRequestDTO proposeDTO = new ProposeSlotRequestDTO();
        proposeDTO.setProposedDate(LocalDateTime.now().plusDays(5));
        proposeDTO.setComments("Justification test");
        proposeDTO.setVisitMode(VisitMode.IN_PERSON);

        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/propose-slot")
                        .header("Authorization", "Bearer " + nurseToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(proposeDTO)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.PROPOSED_MEDECIN.toString()))
                .andExpect(jsonPath("$.visitMode").value("IN_PERSON"));

        // 5. Verify notifications for APPOINTMENT_SLOT_PROPOSED (nurse should not be notified)
        ArgumentCaptor<java.util.List<User>> usersCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(usersCaptor.capture(), any(), eq("APPOINTMENT_SLOT_PROPOSED"), any());
        Set<String> notifiedUserEmails = usersCaptor.getValue().stream().map(User::getEmail).collect(Collectors.toSet());
        assertThat(notifiedUserEmails)
                .contains(employeeUser.getEmail(), manager1User.getEmail(), manager2User.getEmail(), rhUser.getEmail())
                .doesNotContain(nurseUser.getEmail());

        // Assert message content differences by recipient for slot proposal
        ArgumentCaptor<User> uCap2 = ArgumentCaptor.forClass(User.class);
        ArgumentCaptor<String> titleCap2 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> msgCap2 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<NotificationType> typeCap2 = ArgumentCaptor.forClass(NotificationType.class);
        ArgumentCaptor<String> urlCap2 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> relTypeCap2 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Long> relIdCap2 = ArgumentCaptor.forClass(Long.class);

        verify(inAppNotificationService, atLeastOnce()).sendGeneralNotification(
                uCap2.capture(), titleCap2.capture(), msgCap2.capture(), typeCap2.capture(), urlCap2.capture(), relTypeCap2.capture(), relIdCap2.capture());

        String empMsg = null, rhMsg2 = null, mgr1Msg = null, nurseGotMsg = null;
        for (int i = 0; i < uCap2.getAllValues().size(); i++) {
            if (!"Créneau proposé".equals(titleCap2.getAllValues().get(i))) continue;
            String email = uCap2.getAllValues().get(i).getEmail();
            String message = msgCap2.getAllValues().get(i);
            if (email.equals(employeeUser.getEmail())) empMsg = message;
            if (email.equals(rhUser.getEmail())) rhMsg2 = message;
            if (email.equals(manager1User.getEmail())) mgr1Msg = message;
            if (email.equals(nurseUser.getEmail())) nurseGotMsg = message;
        }
        assertThat(empMsg).isNotNull();
        assertThat(empMsg).contains("Un nouveau créneau vous a été proposé :");
        assertThat(empMsg).contains("Justification : Justification test");
        assertThat(empMsg).contains("Confirmez ou refusez.");

        assertThat(rhMsg2).isNotNull();
        assertThat(rhMsg2).contains("Un nouveau créneau a été proposé pour un rendez-vous médical");
        assertThat(mgr1Msg).isNotNull();
        assertThat(mgr1Msg).contains("Un nouveau créneau a été proposé pour un rendez-vous médical");
        assertThat(nurseGotMsg).isNull(); // nurse should not be notified for proposal
    }

    @Test
    @DisplayName("Employee confirms proposed slot -> status CONFIRMED and notifications sent")
    public void testEmployeeConfirmationFlow() throws Exception {
        // Setup users
        setUpTestUsersAndEmployees();

        // Employee creates an appointment
        LoginRequest employeeLogin = new LoginRequest(employeeUser.getEmail(), "password");
        String employeeLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(employeeLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String employeeToken = objectMapper.readTree(employeeLoginResponse).get("token").asText();

        AppointmentRequestDTO requestDTO = new AppointmentRequestDTO();
        requestDTO.setRequestedDateEmployee(LocalDateTime.now().plusDays(2));
        requestDTO.setType(AppointmentType.SPONTANEOUS);
        MvcResult createResult = mockMvc.perform(post("/api/v1/appointments/Rendez-vous-spontanee")
                        .header("Authorization", "Bearer " + employeeToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestDTO)))
                .andExpect(status().isCreated())
                .andReturn();
        Long appointmentId = objectMapper.readTree(createResult.getResponse().getContentAsString()).get("id").asLong();

        // Nurse proposes a slot
        LoginRequest nurseLogin = new LoginRequest(nurseUser.getEmail(), "password");
        String nurseLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(nurseLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String nurseToken = objectMapper.readTree(nurseLoginResponse).get("token").asText();

        ProposeSlotRequestDTO proposeDTO = new ProposeSlotRequestDTO();
        proposeDTO.setProposedDate(LocalDateTime.now().plusDays(4));
        proposeDTO.setVisitMode(VisitMode.IN_PERSON);
        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/propose-slot")
                        .header("Authorization", "Bearer " + nurseToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(proposeDTO)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.PROPOSED_MEDECIN.toString()));

        // Employee confirms the appointment
        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/confirm")
                        .header("Authorization", "Bearer " + employeeToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.CONFIRMED.toString()));

        // Verify a notification to the employee (APPOINTMENT_CONFIRMED)
        ArgumentCaptor<java.util.List<User>> employeeNotifCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(employeeNotifCaptor.capture(), any(), eq("APPOINTMENT_CONFIRMED"), any());
        Set<String> confirmedRecipients = employeeNotifCaptor.getValue().stream().map(User::getEmail).collect(Collectors.toSet());
        assertThat(confirmedRecipients).containsExactly(employeeUser.getEmail());

        // Verify a notification to other actors (APPOINTMENT_CONFIRMED)
        ArgumentCaptor<java.util.List<User>> othersNotifCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(othersNotifCaptor.capture(), any(), eq("APPOINTMENT_CONFIRMED"), any());
        Set<String> othersRecipients = othersNotifCaptor.getValue().stream().map(User::getEmail).collect(Collectors.toSet());
        assertThat(othersRecipients)
                .contains(manager1User.getEmail(), manager2User.getEmail(), nurseUser.getEmail(), rhUser.getEmail())
                .doesNotContain(employeeUser.getEmail());

        // Assert the message differences for employee vs others
        ArgumentCaptor<User> uCap3 = ArgumentCaptor.forClass(User.class);
        ArgumentCaptor<String> titleCap3 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> msgCap3 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<NotificationType> typeCap3 = ArgumentCaptor.forClass(NotificationType.class);
        ArgumentCaptor<String> urlCap3 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> relTypeCap3 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Long> relIdCap3 = ArgumentCaptor.forClass(Long.class);

        verify(inAppNotificationService, atLeastOnce()).sendGeneralNotification(
                uCap3.capture(), titleCap3.capture(), msgCap3.capture(), typeCap3.capture(), urlCap3.capture(), relTypeCap3.capture(), relIdCap3.capture());

        String empConfirmedMsg = null, nurseConfirmedByEmpMsg = null;
        for (int i = 0; i < uCap3.getAllValues().size(); i++) {
            if (!"Rendez-vous confirmé".equals(titleCap3.getAllValues().get(i))) continue;
            String email = uCap3.getAllValues().get(i).getEmail();
            String message = msgCap3.getAllValues().get(i);
            if (email.equals(employeeUser.getEmail())) empConfirmedMsg = message;
            if (email.equals(nurseUser.getEmail())) nurseConfirmedByEmpMsg = message;
        }
        assertThat(empConfirmedMsg).isNotNull();
        assertThat(empConfirmedMsg).contains("Votre rendez-vous médical a été confirmé pour le");
        // For this test we didn't set motif/notes; ensure no sensitive fields appended
        assertThat(empConfirmedMsg).doesNotContain("– Motif :");
        assertThat(empConfirmedMsg).doesNotContain("– Notes :");

        assertThat(nurseConfirmedByEmpMsg).isNotNull();
        assertThat(nurseConfirmedByEmpMsg).contains("Le collaborateur a confirmé le rendez-vous");
        assertThat(nurseConfirmedByEmpMsg).contains("(" + employeeUser.getEmail() + ")");
    }

    @Test
    @DisplayName("Add comment to confirmed appointment -> comment persisted and notifications sent")
    public void testAddCommentFlow() throws Exception {
        // Setup users
        setUpTestUsersAndEmployees();

        // Employee creates appointment
        LoginRequest employeeLogin = new LoginRequest(employeeUser.getEmail(), "password");
        String employeeLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(employeeLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String employeeToken = objectMapper.readTree(employeeLoginResponse).get("token").asText();

        AppointmentRequestDTO requestDTO = new AppointmentRequestDTO();
        requestDTO.setRequestedDateEmployee(LocalDateTime.now().plusDays(2));
        requestDTO.setType(AppointmentType.SPONTANEOUS);
        MvcResult createResult = mockMvc.perform(post("/api/v1/appointments/Rendez-vous-spontanee")
                        .header("Authorization", "Bearer " + employeeToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestDTO)))
                .andExpect(status().isCreated())
                .andReturn();
        Long appointmentId = objectMapper.readTree(createResult.getResponse().getContentAsString()).get("id").asLong();

        // Nurse proposes without comment
        LoginRequest nurseLogin = new LoginRequest(nurseUser.getEmail(), "password");
        String nurseLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(nurseLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String nurseToken = objectMapper.readTree(nurseLoginResponse).get("token").asText();

        ProposeSlotRequestDTO proposeDTO = new ProposeSlotRequestDTO();
        proposeDTO.setProposedDate(LocalDateTime.now().plusDays(4));
        proposeDTO.setVisitMode(VisitMode.IN_PERSON);
        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/propose-slot")
                        .header("Authorization", "Bearer " + nurseToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(proposeDTO)))
                .andExpect(status().isOk());

        // Employee confirms
        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/confirm")
                        .header("Authorization", "Bearer " + employeeToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.CONFIRMED.toString()));

        // Nurse adds a comment
        AppointmentCommentRequestDTO commentRequest = new AppointmentCommentRequestDTO();
        commentRequest.setComment("Observation ajoutée par infirmier");
        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/comments")
                        .header("Authorization", "Bearer " + nurseToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(commentRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.CONFIRMED.toString()))
                .andExpect(jsonPath("$.comments[0].comment").value("Observation ajoutée par infirmier"));

        // Verify notifications for APPOINTMENT_CONFIRMED (nurse should be excluded)
        ArgumentCaptor<java.util.List<User>> usersCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(usersCaptor.capture(), any(), eq("APPOINTMENT_CONFIRMED"), any());
        Set<String> recipients = usersCaptor.getValue().stream().map(User::getEmail).collect(Collectors.toSet());
        assertThat(recipients)
                .contains(employeeUser.getEmail(), manager1User.getEmail(), manager2User.getEmail(), rhUser.getEmail())
                .doesNotContain(nurseUser.getEmail());

        // Assert content of comment-added notification
        ArgumentCaptor<User> uCap4 = ArgumentCaptor.forClass(User.class);
        ArgumentCaptor<String> titleCap4 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> msgCap4 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<NotificationType> typeCap4 = ArgumentCaptor.forClass(NotificationType.class);
        ArgumentCaptor<String> urlCap4 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> relTypeCap4 = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Long> relIdCap4 = ArgumentCaptor.forClass(Long.class);

        verify(inAppNotificationService, atLeastOnce()).sendGeneralNotification(
                uCap4.capture(), titleCap4.capture(), msgCap4.capture(), typeCap4.capture(), urlCap4.capture(), relTypeCap4.capture(), relIdCap4.capture());

        boolean foundCommentNotif = false;
        for (int i = 0; i < titleCap4.getAllValues().size(); i++) {
            if ("Nouveau commentaire".equals(titleCap4.getAllValues().get(i))) {
                assertThat(msgCap4.getAllValues().get(i)).contains("Un commentaire a été ajouté au rendez-vous");
                foundCommentNotif = true;
                break;
            }
        }
        assertThat(foundCommentNotif).isTrue();
    }

    @Test
    @DisplayName("Complete scenario: Employee request with motif/notes -> Nurse direct confirmation -> Verify all emails and notifications")
    public void testCompleteScenarioDirectConfirmation() throws Exception {
        setUpTestUsersAndEmployees();

        // 1. Employee creates appointment with motif and notes
        LoginRequest employeeLogin = new LoginRequest(employeeUser.getEmail(), "password");
        String employeeLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(employeeLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String employeeToken = objectMapper.readTree(employeeLoginResponse).get("token").asText();

        AppointmentRequestDTO requestDTO = new AppointmentRequestDTO();
        requestDTO.setRequestedDateEmployee(LocalDateTime.now().plusDays(5));
        requestDTO.setMotif("Visite de reprise");
        requestDTO.setNotes("Néant");
        requestDTO.setType(AppointmentType.SPONTANEOUS);
        requestDTO.setVisitMode(VisitMode.IN_PERSON);

        MvcResult createResult = mockMvc.perform(post("/api/v1/appointments/Rendez-vous-spontanee")
                        .header("Authorization", "Bearer " + employeeToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestDTO)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.REQUESTED_EMPLOYEE.toString()))
                .andExpect(jsonPath("$.motif").value("Visite de reprise"))
                .andExpect(jsonPath("$.notes").value("Néant"))
                .andReturn();

        Long appointmentId = objectMapper.readTree(createResult.getResponse().getContentAsString()).get("id").asLong();

        // Verify email subject for APPOINTMENT_REQUESTED
        ArgumentCaptor<java.util.List<User>> emailRecipientsCaptor = ArgumentCaptor.forClass(java.util.List.class);
        ArgumentCaptor<com.oshapp.backend.model.Appointment> emailAppointmentCaptor = ArgumentCaptor.forClass(com.oshapp.backend.model.Appointment.class);
        ArgumentCaptor<String> emailSubjectCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> emailTemplateCaptor = ArgumentCaptor.forClass(String.class);

        verify(emailService, atLeastOnce()).sendAppointmentNotification(
                emailRecipientsCaptor.capture(), emailAppointmentCaptor.capture(), emailSubjectCaptor.capture(), emailTemplateCaptor.capture(), any(), any());

        // Check that email subject contains employee name
        boolean foundCorrectSubject = false;
        for (String subject : emailSubjectCaptor.getAllValues()) {
            if (subject.contains("Nouvelle demande de rendez-vous médical") && subject.contains("Employee User")) {
                foundCorrectSubject = true;
                break;
            }
        }
        assertThat(foundCorrectSubject).isTrue();

        // 2. Nurse confirms directly (without proposing)
        LoginRequest nurseLogin = new LoginRequest(nurseUser.getEmail(), "password");
        String nurseLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(nurseLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String nurseToken = objectMapper.readTree(nurseLoginResponse).get("token").asText();

        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/confirm")
                        .header("Authorization", "Bearer " + nurseToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.CONFIRMED.toString()));

        // Verify APPOINTMENT_CONFIRMED notifications for non-RH recipients (actor: MEDICAL_STAFF)
        ArgumentCaptor<java.util.List<User>> confirmedUsersCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(confirmedUsersCaptor.capture(), any(), eq("APPOINTMENT_CONFIRMED"), any(), eq(com.oshapp.backend.service.notifications.NotificationActor.MEDICAL_STAFF));

        // Verify APPOINTMENT_CONFIRMED_RH notifications for RH users (actor: RH)
        ArgumentCaptor<java.util.List<User>> rhUsersCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(rhUsersCaptor.capture(), any(), eq("APPOINTMENT_CONFIRMED_RH"), any(), eq(com.oshapp.backend.service.notifications.NotificationActor.RH));

        // Verify email subjects for confirmation
        ArgumentCaptor<String> confirmSubjectCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailService, atLeastOnce()).sendAppointmentNotification(
                any(), any(), confirmSubjectCaptor.capture(), any());

        boolean foundConfirmationSubject = false;
        for (String subject : confirmSubjectCaptor.getAllValues()) {
            if (subject.contains("Confirmation de votre rendez-vous médical") || subject.contains("Confirmation de rendez-vous médical")) {
                foundConfirmationSubject = true;
                break;
            }
        }
        assertThat(foundConfirmationSubject).isTrue();

        // Verify in-app notification content for RH recipient uses privacy-filtered format
        ArgumentCaptor<User> uCapConfirm = ArgumentCaptor.forClass(User.class);
        ArgumentCaptor<String> titleCapConfirm = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> msgCapConfirm = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<com.oshapp.backend.model.enums.NotificationType> typeCapConfirm = ArgumentCaptor.forClass(com.oshapp.backend.model.enums.NotificationType.class);
        ArgumentCaptor<String> urlCapConfirm = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> relTypeCapConfirm = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<Long> relIdCapConfirm = ArgumentCaptor.forClass(Long.class);

        verify(inAppNotificationService, atLeastOnce()).sendGeneralNotification(
                uCapConfirm.capture(), titleCapConfirm.capture(), msgCapConfirm.capture(), typeCapConfirm.capture(), urlCapConfirm.capture(), relTypeCapConfirm.capture(), relIdCapConfirm.capture());

        String rhConfirmedMsg = null;
        for (int i = 0; i < uCapConfirm.getAllValues().size(); i++) {
            if (!"Rendez-vous confirmé".equals(titleCapConfirm.getAllValues().get(i))) continue;
            if (uCapConfirm.getAllValues().get(i).getEmail().equals(rhUser.getEmail())) {
                rhConfirmedMsg = msgCapConfirm.getAllValues().get(i);
                break;
            }
        }
        assertThat(rhConfirmedMsg).isNotNull();
        String expectedRhMsg = String.format("Le service médical a confirmé la validation d'un rendez-vous pour %s – %s – Statut : Confirmé.",
                "Employee User", employeeUser.getEmail());
        assertThat(rhConfirmedMsg).isEqualTo(expectedRhMsg);

        // Verify notification message contains employee email
        ArgumentCaptor<String> messageCaptor = ArgumentCaptor.forClass(String.class);
        verify(multiNotifService, atLeastOnce()).notifyUsers(
                any(), any(), eq("APPOINTMENT_REQUESTED"), messageCaptor.capture());
        String capturedMessage = messageCaptor.getValue();
        assertThat(capturedMessage).contains(employeeUser.getEmail());
    }

    @Test
    @DisplayName("Complete scenario: Employee request -> Nurse proposes slot -> Employee confirms -> Verify all notifications")
    public void testCompleteScenarioWithProposal() throws Exception {
        setUpTestUsersAndEmployees();

        // 1. Employee creates appointment
        LoginRequest employeeLogin = new LoginRequest(employeeUser.getEmail(), "password");
        String employeeLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(employeeLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String employeeToken = objectMapper.readTree(employeeLoginResponse).get("token").asText();

        AppointmentRequestDTO requestDTO = new AppointmentRequestDTO();
        requestDTO.setRequestedDateEmployee(LocalDateTime.now().plusDays(3));
        requestDTO.setMotif("Visite de reprise");
        requestDTO.setNotes("ehhh");
        requestDTO.setType(AppointmentType.SPONTANEOUS);

        MvcResult createResult = mockMvc.perform(post("/api/v1/appointments/Rendez-vous-spontanee")
                        .header("Authorization", "Bearer " + employeeToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestDTO)))
                .andExpect(status().isCreated())
                .andReturn();

        Long appointmentId = objectMapper.readTree(createResult.getResponse().getContentAsString()).get("id").asLong();

        // 2. Nurse proposes new slot
        LoginRequest nurseLogin = new LoginRequest(nurseUser.getEmail(), "password");
        String nurseLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(nurseLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String nurseToken = objectMapper.readTree(nurseLoginResponse).get("token").asText();

        ProposeSlotRequestDTO proposeDTO = new ProposeSlotRequestDTO();
        proposeDTO.setProposedDate(LocalDateTime.now().plusDays(7));
        proposeDTO.setComments("Indisponibilité du médecin");
        proposeDTO.setVisitMode(VisitMode.REMOTE);

        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/propose-slot")
                        .header("Authorization", "Bearer " + nurseToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(proposeDTO)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.PROPOSED_MEDECIN.toString()))
                .andExpect(jsonPath("$.visitMode").value("REMOTE"));

        // Verify APPOINTMENT_SLOT_PROPOSED email subject
        ArgumentCaptor<String> proposalSubjectCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailService, atLeastOnce()).sendAppointmentNotification(
                any(), any(), proposalSubjectCaptor.capture(), any(), any(), any());

        boolean foundProposalSubject = false;
        for (String subject : proposalSubjectCaptor.getAllValues()) {
            if (subject.contains("Nouveau créneau proposé pour votre rendez-vous médical")) {
                foundProposalSubject = true;
                break;
            }
        }
        assertThat(foundProposalSubject).isTrue();

        // 3. Employee confirms the proposed slot
        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/confirm")
                        .header("Authorization", "Bearer " + employeeToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.CONFIRMED.toString()));

        // Verify APPOINTMENT_CONFIRMED notifications
        ArgumentCaptor<java.util.List<User>> employeeConfirmedCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(employeeConfirmedCaptor.capture(), any(), eq("APPOINTMENT_CONFIRMED"), any());

        Set<String> employeeConfirmedRecipients = employeeConfirmedCaptor.getValue().stream().map(User::getEmail).collect(Collectors.toSet());
        assertThat(employeeConfirmedRecipients)
                .contains(nurseUser.getEmail(), rhUser.getEmail(), manager1User.getEmail(), manager2User.getEmail())
                .doesNotContain(employeeUser.getEmail());

        // Verify email subject for employee confirmation
        ArgumentCaptor<String> employeeConfirmSubjectCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailService, atLeastOnce()).sendAppointmentNotification(
                any(), any(), employeeConfirmSubjectCaptor.capture(), any(), any(), any());

        boolean foundEmployeeConfirmSubject = false;
        for (String subject : employeeConfirmSubjectCaptor.getAllValues()) {
            if (subject.contains("Confirmation du créneau proposé") && subject.contains("Employee User")) {
                foundEmployeeConfirmSubject = true;
                break;
            }
        }
        assertThat(foundEmployeeConfirmSubject).isTrue();
    }

    @Test
    @DisplayName("Cancellation scenario: Employee cancels appointment -> Verify cancellation notifications and emails")
    public void testCancellationScenario() throws Exception {
        setUpTestUsersAndEmployees();

        // 1. Employee creates appointment
        LoginRequest employeeLogin = new LoginRequest(employeeUser.getEmail(), "password");
        String employeeLoginResponse = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(employeeLogin)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String employeeToken = objectMapper.readTree(employeeLoginResponse).get("token").asText();

        AppointmentRequestDTO requestDTO = new AppointmentRequestDTO();
        LocalDateTime requestedDate = LocalDateTime.now().plusDays(3);
        requestDTO.setRequestedDateEmployee(requestedDate);
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
        String expectedWhen = requestedDate.format(fmt);
        requestDTO.setMotif("Visite de reprise");
        requestDTO.setType(AppointmentType.SPONTANEOUS);

        MvcResult createResult = mockMvc.perform(post("/api/v1/appointments/Rendez-vous-spontanee")
                        .header("Authorization", "Bearer " + employeeToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(requestDTO)))
                .andExpect(status().isCreated())
                .andReturn();

        Long appointmentId = objectMapper.readTree(createResult.getResponse().getContentAsString()).get("id").asLong();

        // 2. Employee cancels the appointment
        String cancellationReason = "Indisponibilité de l'employé";
        CancelRequestDTO cancelRequest = new CancelRequestDTO();
        cancelRequest.setReason(cancellationReason);
        
        mockMvc.perform(post("/api/v1/appointments/" + appointmentId + "/cancel")
                        .header("Authorization", "Bearer " + employeeToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(cancelRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(AppointmentStatus.CANCELLED.toString()))
                .andExpect(jsonPath("$.cancellationReason").value(cancellationReason));

        // Verify APPOINTMENT_CANCELLED notifications
        ArgumentCaptor<java.util.List<User>> cancelledUsersCaptor = ArgumentCaptor.forClass(java.util.List.class);
        verify(multiNotifService).notifyUsers(cancelledUsersCaptor.capture(), any(), eq("APPOINTMENT_CANCELLED"), any());
        ArgumentCaptor<User> cancelUserCaptor = ArgumentCaptor.forClass(User.class);
        ArgumentCaptor<String> cancelTitleCaptor = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> cancelMsgCaptor = ArgumentCaptor.forClass(String.class);
        verify(inAppNotificationService, atLeastOnce()).sendGeneralNotification(
                cancelUserCaptor.capture(), cancelTitleCaptor.capture(), cancelMsgCaptor.capture(), any(), any(), any(), any());

        boolean foundCancelNotification = false;
        for (int i = 0; i < cancelTitleCaptor.getAllValues().size(); i++) {
            if ("Rendez-vous annulé".equals(cancelTitleCaptor.getAllValues().get(i))) {
                String message = cancelMsgCaptor.getAllValues().get(i);
                // Verify backend-composed message with canonical date, mode and status
                assertThat(message).contains("Vous avez annulé votre demande de rendez-vous");
                assertThat(message).contains("Date demandée : " + expectedWhen);
                assertThat(message).contains("Mode : À distance");
                assertThat(message).contains("Statut : Annulé.");
                foundCancelNotification = true;
                break;
            }
        }
        assertThat(foundCancelNotification).isTrue();

        // Verify cancellation email subject contains employee identity
        ArgumentCaptor<String> cancelEmailSubjectCaptor = ArgumentCaptor.forClass(String.class);
        verify(emailService, atLeastOnce()).sendAppointmentNotification(
                any(), any(), cancelEmailSubjectCaptor.capture(), any(), any(), any());

        boolean foundCancelSubject = false;
        for (String subject : cancelEmailSubjectCaptor.getAllValues()) {
            if (subject.contains("Annulation (Spontané)")
                    && subject.contains("Employee User")
                    && subject.contains("(" + employeeUser.getEmail() + ")")) {
                foundCancelSubject = true;
                break;
            }
        }
        assertThat(foundCancelSubject).isTrue();
    }
}
