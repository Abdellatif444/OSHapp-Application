package com.oshapp.backend.model;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;

@Entity
public class Company {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String address;
    private String phone;
    private String email;
    private String siret;
    private String sector;
    private Integer headcount;
    private String website;
    private String logoUrl;
    // New optional fields
    private String insurerAtMp; // Assureur AT/MP
    private String insurerHorsAtMp; // Assureur spécialisé hors AT/MP
    private String otherSocialContributions; // Autres cotisations sociales
    private String additionalDetails; // Détails supplémentaires

    // Getters and Setters

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getAddress() {
        return address;
    }

    public void setAddress(String address) {
        this.address = address;
    }

    public String getPhone() {
        return phone;
    }

    public void setPhone(String phone) {
        this.phone = phone;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getSiret() {
        return siret;
    }

    public void setSiret(String siret) {
        this.siret = siret;
    }
    
    public String getSector() {
        return sector;
    }

    public void setSector(String sector) {
        this.sector = sector;
    }

    public Integer getHeadcount() {
        return headcount;
    }

    public void setHeadcount(Integer headcount) {
        this.headcount = headcount;
    }
    
    // Méthodes d'alias pour compatibilité
    public String getPhoneNumber() {
        return this.phone;
    }
    
    public String getWebsite() {
        return this.website;
    }
    
    public String getLogoUrl() {
        return this.logoUrl;
    }

    // Méthodes d'alias pour les setters
    public void setPhoneNumber(String phone) {
        this.phone = phone;
    }

    public void setWebsite(String website) {
        this.website = website;
    }

    public void setLogoUrl(String logoUrl) {
        this.logoUrl = logoUrl;
    }

    public String getInsurerAtMp() {
        return insurerAtMp;
    }

    public void setInsurerAtMp(String insurerAtMp) {
        this.insurerAtMp = insurerAtMp;
    }

    public String getInsurerHorsAtMp() {
        return insurerHorsAtMp;
    }

    public void setInsurerHorsAtMp(String insurerHorsAtMp) {
        this.insurerHorsAtMp = insurerHorsAtMp;
    }

    public String getOtherSocialContributions() {
        return otherSocialContributions;
    }

    public void setOtherSocialContributions(String otherSocialContributions) {
        this.otherSocialContributions = otherSocialContributions;
    }

    public String getAdditionalDetails() {
        return additionalDetails;
    }

    public void setAdditionalDetails(String additionalDetails) {
        this.additionalDetails = additionalDetails;
    }
}
