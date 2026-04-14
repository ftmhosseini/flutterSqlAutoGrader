import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../services/user_session.dart';

class DashboardShell extends StatelessWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final role = UserSession.role;
    final isTeacher = role == 'teacher';
    final loc = GoRouterState.of(context).matchedLocation;

    final drawerItems = isTeacher
        ? [
            _NavItem('Services', '/dashboard', Icons.apps),
            _NavItem(
              'Overview',
              '/dashboard/teacher/overview',
              Icons.dashboard,
            ),
            _NavItem('Cohorts', '/dashboard/teacher/cohorts', Icons.group),
            _NavItem(
              'Assignments',
              '/dashboard/teacher/assignments',
              Icons.book,
            ),
            _NavItem('Datasets', '/dashboard/teacher/datasets', Icons.storage),
            _NavItem('Quizzes', '/dashboard/teacher/quizzes', Icons.quiz),
            _NavItem(
              'Submissions',
              '/dashboard/teacher/submissions',
              Icons.check_circle,
            ),
            _NavItem('Profile', '/dashboard/profile', Icons.person),
          ]
        : [
            _NavItem('Dashboard', '/dashboard', Icons.dashboard),
            _NavItem(
              'Assignments',
              '/dashboard/student/assignments',
              Icons.book,
            ),
            _NavItem('Quizzes', '/dashboard/student/quizzes', Icons.quiz),
            _NavItem('Results', '/dashboard/student/results', Icons.bar_chart),
            _NavItem('Cohorts', '/dashboard/student/cohorts', Icons.group),
            _NavItem('SQL Tutor', '/dashboard/student/tutor', Icons.smart_toy),
            _NavItem('Profile', '/dashboard/profile', Icons.person),
          ];

    final bottomItems = isTeacher
        ? [
            _NavItem('Services', '/dashboard', Icons.apps),
            _NavItem(
              'Overview',
              '/dashboard/teacher/overview',
              Icons.dashboard,
            ),
            _NavItem(
              'Assignments',
              '/dashboard/teacher/assignments',
              Icons.book,
            ),
            _NavItem('Quizzes', '/dashboard/teacher/quizzes', Icons.quiz),
            _NavItem(
              'Submissions',
              '/dashboard/teacher/submissions',
              Icons.check_circle,
            ),
          ]
        : [
            _NavItem('Dashboard', '/dashboard', Icons.dashboard),
            _NavItem(
              'Assignments',
              '/dashboard/student/assignments',
              Icons.book,
            ),
            _NavItem('Quizzes', '/dashboard/student/quizzes', Icons.quiz),
            _NavItem('Tutor', '/dashboard/student/tutor', Icons.smart_toy),
            _NavItem('Profile', '/dashboard/profile', Icons.person),
          ];

    int selectedIndex = 0;
    for (int i = 0; i < bottomItems.length; i++) {
      if (bottomItems[i].path == '/dashboard' && loc == '/dashboard') {
        selectedIndex = i;
        break;
      }
      if (bottomItems[i].path != '/dashboard' &&
          loc.startsWith(bottomItems[i].path)) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4e73df),
        title: Text(
          isTeacher ? 'Teacher Dashboard' : 'Student Dashboard',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              UserSession.clear();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      // drawer: NavigationDrawer(
      //   children: [
      //     DrawerHeader(
      //       decoration: const BoxDecoration(color: Color(0xFF4e73df)),
      //       child: Column(
      //         crossAxisAlignment: CrossAxisAlignment.start,
      //         mainAxisAlignment: MainAxisAlignment.end,
      //         children: [
      //           CircleAvatar(
      //             backgroundColor: Colors.white,
      //             child: Text(
      //               (UserSession.fullName ?? 'U')[0].toUpperCase(),
      //               style: const TextStyle(
      //                 color: Color(0xFF4e73df),
      //                 fontWeight: FontWeight.bold,
      //               ),
      //             ),
      //           ),
      //           const SizedBox(height: 8),
      //           Text(
      //             UserSession.fullName ?? '',
      //             style: const TextStyle(
      //               color: Colors.white,
      //               fontWeight: FontWeight.bold,
      //             ),
      //           ),
      //           Text(
      //             UserSession.email ?? '',
      //             style: const TextStyle(color: Colors.white70, fontSize: 12),
      //           ),
      //         ],
      //       ),
      //     ),
      //     ...drawerItems.map(
      //       (item) => ListTile(
      //         leading: Icon(item.icon),
      //         title: Text(item.label),
      //         selected: loc == item.path,
      //         onTap: () {
      //           Navigator.pop(context);
      //           context.go(item.path);
      //         },
      //       ),
      //     ),
      //   ],
      // ),
      body: child,
      bottomNavigationBar: isTeacher
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Services / Overview
                Container(
                  color: Colors.white,
                  child: Row(
                    children:loc ==           
      '/dashboard/teacher/overview'? []:[
                      _tabBtn(
                        context,
                        'Assignments',
                        Icons.book,
                        '/dashboard/teacher/assignments',
                        loc == '/dashboard/teacher/assignments',
                      ),
                      _tabBtn(
                        context,
                        'Quizzes',
                        Icons.quiz,
                        '/dashboard/teacher/quizzes',
                        loc == '/dashboard/teacher/quizzes',
                      ),
                      _tabBtn(
                        context,
                        'Datasets',
                        Icons.storage,
                        '/dashboard/teacher/datasets',
                        loc == '/dashboard/teacher/datasets',
                      ),
                      _tabBtn(
                        context,
                        'Submissions',
                        Icons.check_circle,
                        '/dashboard/teacher/submissions',
                        loc == '/dashboard/teacher/submissions',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Bottom row: main pages
                BottomNavigationBar(
                  currentIndex: () {
                    if (loc == '/dashboard/teacher/overview') return 1;
                   return 0; 
                  }(),
                  onTap: (i) => context.go(
                    ['/dashboard', '/dashboard/teacher/overview'][i],
                  ),
                  selectedItemColor: const Color(0xFF4e73df),
                  unselectedItemColor: Colors.grey,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.apps),
                      label: 'Services',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard),
                      label: 'Overview',
                    ),
                 ],
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  child: Row(
                    children: loc == '/dashboard/student/overview' ? [] : [
                      _tabBtn(context, 'Assignments', Icons.book, '/dashboard/student/assignments', loc.startsWith('/dashboard/student/assignments')),
                      _tabBtn(context, 'Quizzes', Icons.quiz, '/dashboard/student/quizzes', loc.startsWith('/dashboard/student/quizzes')),
                      _tabBtn(context, 'Results', Icons.bar_chart, '/dashboard/student/results', loc.startsWith('/dashboard/student/results')),
                      // _tabBtn(context, 'Cohorts', Icons.group, '/dashboard/student/cohorts', loc.startsWith('/dashboard/student/cohorts')),
                      _tabBtn(context, 'Tutor', Icons.smart_toy, '/dashboard/student/tutor', loc.startsWith('/dashboard/student/tutor')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                BottomNavigationBar(
                  currentIndex: loc == '/dashboard/student/overview' ? 1 : 0,
                  onTap: (i) => context.go(
                    ['/dashboard', '/dashboard/student/overview'][i],
                  ),
                  selectedItemColor: const Color(0xFF4e73df),
                  unselectedItemColor: Colors.grey,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Services'),
                    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _NavItem {
  final String label, path;
  final IconData icon;
  const _NavItem(this.label, this.path, this.icon);
}

Widget _tabBtn(
  BuildContext context,
  String label,
  IconData icon,
  String path,
  bool selected,
) => Expanded(
  child: InkWell(
    onTap: () => context.go(path),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? const Color(0xFF4e73df) : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: selected ? const Color(0xFF4e73df) : Colors.grey,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? const Color(0xFF4e73df) : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    ),
  ),
);
