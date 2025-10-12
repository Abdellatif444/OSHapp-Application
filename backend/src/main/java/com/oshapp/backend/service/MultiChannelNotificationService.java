package com.oshapp.backend.service;

import com.oshapp.backend.model.Appointment;
import com.oshapp.backend.model.User;
import com.oshapp.backend.service.notifications.NotificationActor;

import java.util.List;
import java.util.Set;


public interface MultiChannelNotificationService {


    void notifyUsersWithChannels(Set<User> users, String title, String message, List<String> channels);
    /**
     * Envoie une notification multi-canal pour un nouveau rendez-vous
     * Selon le scénario : Application + Email + SMS
     */
    void sendAppointmentNotification(User user, Appointment appointment);

    /**
     * Envoie une notification multi-canal pour un changement de statut
     * Selon le scénario : Application + Email + SMS
     */
    void sendAppointmentStatusNotification(User user, Appointment appointment);
    /**
     * Envoie une notification multi-canal pour une visite obligatoire
     * Selon le scénario : Application + Email + SMS
     */
    void sendObligatoryAppointmentNotification(User user, Appointment appointment);
    /**
     * Envoie des notifications multi-canal pour des visites obligatoires en lot
     * Utilisé par le RH pour envoyer des listes de salariés
     */
    void sendBulkObligatoryAppointments(List<User> users, List<Appointment> appointments);
    /**
     * Notifie tous les acteurs concernés selon le scénario
     * - Infirmier(ère)
     * - Médecin du travail  
     * - Responsable RH
     * - Chef hiérarchique N+1 et N+2
     */
    void notifyAllActors(Appointment appointment, List<User> actors);
    /**
     * Notifie spécifiquement les managers N+1 et N+2 d'une proposition de créneau
     * Selon le scénario : les managers peuvent signaler une indisponibilité
     */
    void notifyManagersOfProposal(Appointment appointment, List<User> managers);
    /**
     * Notifie le salarié et les managers de la confirmation d'un rendez-vous
     */
    void notifyConfirmation(Appointment appointment, User employee, List<User> managers);

    /**
     * Notifie une liste d'utilisateurs selon le scénario métier (factorisation)
     * scenario: "CREATION", "STATUS_UPDATE", "CONFIRMATION", "OBLIGATORY"
     * extraMessage: message additionnel pour certains scénarios (ex: motif de report)
     */
    void notifyUsers(List<User> users, Appointment appointment, String scenario, String extraMessage);
    
    /**
     * Variante actor-aware de notifyUsers permettant de préciser explicitement l'acteur
     * à l'origine de l'action (ex: EMPLOYEE, MEDICAL_STAFF, RH). Utile lorsque le scénario
     * ne permet pas d'inférer correctement l'acteur.
     */
    void notifyUsers(List<User> users, Appointment appointment, String scenario, String extraMessage, NotificationActor actor);
    
    /**
     * Envoie un email de notification
     */
    void sendEmailNotification(String email, String subject, String content);
    
    /**
     * Envoie une notification in-app
     */
    void sendInAppNotification(Long userId, String title, String message);
} 