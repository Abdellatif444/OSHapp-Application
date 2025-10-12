package com.oshapp.backend.repository;

import com.oshapp.backend.model.Employee;
import com.oshapp.backend.model.User;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, Long> {

    Optional<Employee> findByUserId(Long userId);

    @EntityGraph(attributePaths = {"user"})
    Optional<Employee> findByUserEmail(String email);

    Optional<Employee> findByUser(User user);

    @Query("SELECT e FROM Employee e WHERE e.manager1.user.email = :email OR e.manager2.user.email = :email")
    List<Employee> findSubordinatesByManagerEmail(@Param("email") String email);

    List<Employee> findByHireDateAfterOrderByHireDateDesc(LocalDate date);

    List<Employee> findAllByManager1_IdOrManager2_Id(Long manager1Id, Long manager2Id);

    Optional<Employee> findByUserUsername(String username);

    List<Employee> findByManager1(Employee manager);

    List<Employee> findByManager2(Employee manager);

    List<Employee> findByManager1IdOrManager2Id(@Param("manager1Id") Long manager1Id, @Param("manager2Id") Long manager2Id);
}