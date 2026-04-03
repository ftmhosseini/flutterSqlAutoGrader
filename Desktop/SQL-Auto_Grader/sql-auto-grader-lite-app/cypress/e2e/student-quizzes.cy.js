describe('Student Quizzes Page', () => {
  beforeEach(() => {
    cy.loginAsStudent();
    cy.visit('/dashboard/quizzes');
  });

  it('loads quizzes page', () => {
    cy.url().should('include', '/dashboard/quizzes');
  });

  it('shows quizzes list', () => {
    cy.contains('Quizzes').should('be.visible');
  });
});
