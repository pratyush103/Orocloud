import 'package:flutter/material.dart';
                              import 'package:supabase_flutter/supabase_flutter.dart';

                              class ProfilePage extends StatefulWidget {
                                const ProfilePage({super.key});

                                @override
                                State<ProfilePage> createState() => _ProfilePageState();
                              }

                              class _ProfilePageState extends State<ProfilePage> {
                                @override
                                Widget build(BuildContext context) {
                                  return Scaffold(
                                    appBar: AppBar(
                                      title: const Text('Profile'),
                                      actions: <Widget>[
                                        IconButton(
                                          icon: const Icon(Icons.logout),
                                          onPressed: () async {
                                            await Supabase.instance.client.auth
                                                .signOut();
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                    body: Column(
                                      mainAxisAlignment: MainAxisAlignment
                                          .center,
                                      children: const <Widget>[
                                        Text('Profile Page'),
                                      ],
                                    ),
                                  );
                                }
                              }