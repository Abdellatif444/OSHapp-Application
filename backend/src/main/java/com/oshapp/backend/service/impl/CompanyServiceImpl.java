package com.oshapp.backend.service.impl;

import com.oshapp.backend.model.Company;
import com.oshapp.backend.repository.CompanyRepository;
import com.oshapp.backend.service.CompanyService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class CompanyServiceImpl implements CompanyService {

    private final CompanyRepository companyRepository;

    @Override
    public Optional<Company> getCompanyProfile() {
        // Assuming a single company profile, we fetch the first one.
        return companyRepository.findFirst();
    }

    @Override
    public Company updateCompanyProfile(Company companyDetails) {
        Company company = companyRepository.findFirst()
                .orElse(new Company()); // Create new if it doesn't exist

        company.setName(companyDetails.getName());
        company.setAddress(companyDetails.getAddress());
        company.setPhoneNumber(companyDetails.getPhoneNumber());
        company.setEmail(companyDetails.getEmail());
        company.setSiret(companyDetails.getSiret());
        company.setSector(companyDetails.getSector());
        company.setHeadcount(companyDetails.getHeadcount());
        company.setWebsite(companyDetails.getWebsite());
        company.setLogoUrl(companyDetails.getLogoUrl());
        // Optional insurer/social contribution fields
        company.setInsurerAtMp(companyDetails.getInsurerAtMp());
        company.setInsurerHorsAtMp(companyDetails.getInsurerHorsAtMp());
        company.setOtherSocialContributions(companyDetails.getOtherSocialContributions());
        company.setAdditionalDetails(companyDetails.getAdditionalDetails());

        return companyRepository.save(company);
    }

    @Override
    public Company updateCompanyLogo(String logoUrl) {
        Company company = companyRepository.findFirst().orElse(new Company());
        company.setLogoUrl(logoUrl);
        return companyRepository.save(company);
    }
}

