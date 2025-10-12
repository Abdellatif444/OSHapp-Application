package com.oshapp.backend.service;

import com.oshapp.backend.model.Company;

import java.util.Optional;

public interface CompanyService {
    Optional<Company> getCompanyProfile();
    Company updateCompanyProfile(Company companyDetails);
    Company updateCompanyLogo(String logoUrl);
}
