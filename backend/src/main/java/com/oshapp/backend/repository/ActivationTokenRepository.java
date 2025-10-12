package com.oshapp.backend.repository;

import com.oshapp.backend.model.ActivationToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

import com.oshapp.backend.model.User;

public interface ActivationTokenRepository extends JpaRepository<ActivationToken, Long> {

    Optional<ActivationToken> findByToken(String token);

    void deleteByUser(User user);
}
