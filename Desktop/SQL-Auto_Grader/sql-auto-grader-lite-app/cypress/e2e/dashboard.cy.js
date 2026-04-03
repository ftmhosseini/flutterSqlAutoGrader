describe('Student Dashboard', () => {
  beforeEach(() => cy.loginAsStudent());

  it('shows dashboard after login', () => {
    cy.url().should('include', '/dashboard');
  });

  it('shows student navigation items', () => {
    cy.contains('Assignments').should('be.visible');
    cy.contains('Quizzes').should('be.visible');
    cy.contains('Results').should('be.visible');
  });
});

describe('Teacher Dashboard', () => {
  beforeEach(() => cy.loginAsTeacher());

  it('shows dashboard after login', () => {
    cy.url().should('include', '/dashboard');
  });

  it('shows teacher navigation items', () => {
    cy.contains('Assignments').should('be.visible');
    cy.contains('Cohorts').should('be.visible');
    cy.contains('Datasets').should('be.visible');
  });
});
