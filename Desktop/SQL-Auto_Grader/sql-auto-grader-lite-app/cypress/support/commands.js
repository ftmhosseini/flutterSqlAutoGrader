// Custom commands
Cypress.Commands.add('loginAsStudent', () => {
  cy.visit('/login');
  cy.get('input[type="email"]').type(Cypress.env('STUDENT_EMAIL'));
  cy.get('input[type="password"]').type(Cypress.env('STUDENT_PASSWORD'));
  cy.get('button[type="submit"]').click();
  cy.url().should('include', '/dashboard');
});

Cypress.Commands.add('loginAsTeacher', () => {
  cy.visit('/login');
  cy.get('input[type="email"]').type(Cypress.env('TEACHER_EMAIL'));
  cy.get('input[type="password"]').type(Cypress.env('TEACHER_PASSWORD'));
  cy.get('button[type="submit"]').click();
  cy.url().should('include', '/dashboard');
});
