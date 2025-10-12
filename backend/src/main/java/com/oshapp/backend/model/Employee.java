package com.oshapp.backend.model;

import com.fasterxml.jackson.annotation.JsonIdentityInfo;
import com.fasterxml.jackson.annotation.ObjectIdGenerators;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import jakarta.persistence.*;
import java.time.LocalDate;
import com.oshapp.backend.model.enums.Gender;
import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;

@Entity
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIdentityInfo(generator = ObjectIdGenerators.PropertyGenerator.class, property = "id")
public class Employee {

    public Employee(User user) {
        this.user = user;
        this.firstName = user.getEmployee() != null ? user.getEmployee().getFirstName() : "FirstName";
        this.lastName = user.getEmployee() != null ? user.getEmployee().getLastName() : "LastName";
        this.profileCompleted = false;
    }


    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne
    @JoinColumn(name = "user_id", referencedColumnName = "id")
    @NotFound(action = NotFoundAction.IGNORE)
    private User user;

    private String firstName;
    private String lastName;
    private String position;
    private String department;
    private LocalDate hireDate;
    private String cin;
    private String cnss;
    private String phoneNumber;
    private String address;
    private String city;
    private String zipCode;
    private String country;
    private LocalDate birthDate;
    private String birthPlace;
    private String nationality;
    private String employeeId;

    @Enumerated(EnumType.STRING)
    private Gender gender;

    @ManyToOne
    @JoinColumn(name = "manager1_id")
    private Employee manager1;

    @ManyToOne
    @JoinColumn(name = "manager2_id")
    private Employee manager2;

    private boolean profileCompleted;

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Employee employee = (Employee) o;
        return id != null && id.equals(employee.id);
    }

    @Override
    public int hashCode() {
        return id != null ? id.hashCode() : 0;
    }
}
