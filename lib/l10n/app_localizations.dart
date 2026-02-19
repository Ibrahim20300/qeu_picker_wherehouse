class S {
  static String _locale = 'ar';
  static String get locale => _locale;
  static bool get isAr => _locale == 'ar';
  static bool get isEn => _locale == 'en';
  static void setLocale(String l) => _locale = l;

  static String _t(String ar, String en) => isAr ? ar : en;

  // ==================== Common ====================
  static String get retry => _t('إعادة المحاولة', 'Retry');
  static String get cancel => _t('إلغاء', 'Cancel');
  static String get confirm => _t('تأكيد', 'Confirm');
  static String get close => _t('إغلاق', 'Close');
  static String get save => _t('حفظ', 'Save');
  static String get reject => _t('رفض', 'Reject');
  static String get approve => _t('موافقة', 'Approve');
  static String get accept => _t('قبول', 'Accept');
  static String get product => _t('منتج', 'product');
  static String get bag => _t('كيس', 'bag');
  static String get exception => _t('استثناء', 'exception');
  static String get change => _t('تغيير', 'Change');
  static String get search => _t('بحث...', 'Search...');
  static String get orderDetails => _t('تفاصيل الطلب', 'Order Details');

  // ==================== Login ====================
  static String get warehouseManagement => _t('نظام إدارة المستودعات', 'Warehouse Management System');
  static String get phoneNumber => _t('رقم الجوال', 'Phone Number');
  static String get pleaseEnterPhone => _t('الرجاء إدخال رقم الجوال', 'Please enter phone number');
  static String get phoneMustBe10Digits => _t('رقم الجوال يجب أن يكون 10 خانات', 'Phone number must be 10 digits');
  static String get password => _t('كلمة المرور', 'Password');
  static String get pleaseEnterPassword => _t('الرجاء إدخال كلمة المرور', 'Please enter password');
  static String get login => _t('تسجيل الدخول', 'Login');
  static String get testCredentials => _t('بيانات تجريبية للدخول:', 'Test credentials:');
  static String get passwordLabel => _t('كلمة المرور:', 'Password:');

  // ==================== Navigation ====================
  static String get orders => _t('الطلبات', 'Orders');
  static String get myAccount => _t('حسابي', 'My Account');
  static String get orderPreparation => _t('تحضير الطلبات', 'Order Preparation');

  // ==================== Task Status ====================
  static String get statusPending => _t('قيد الانتظار', 'Pending');
  static String get statusAssigned => _t('تم التعيين', 'Assigned');
  static String get statusInProgress => _t('جاري التحضير', 'In Progress');
  static String get statusCompleted => _t('مكتمل', 'Completed');
  static String get statusCancelled => _t('ملغي', 'Cancelled');

  // ==================== Picker Home ====================
  static String get failedToStartPreparation => _t('فشل بدء التحضير. حاول مرة أخرى', 'Failed to start preparation. Try again');
  static String get failedToFetchOrders => _t('فشل جلب الطلبات. تحقق من اتصال الإنترنت', 'Failed to fetch orders. Check internet connection');
  static String get noOrders => _t('لا توجد طلبات', 'No orders');
  static String orderNum(String num) => _t('طلب #$num', 'Order #$num');
  static String get urgent => _t('عاجل', 'Urgent');
  static String get startPreparation => _t('بدء التحضير', 'Start Preparation');

  // ==================== Task Details ====================
  static String get taskDetails => _t('تفاصيل المهمة', 'Task Details');
  static String get products => _t('المنتجات', 'Products');
  static String get completeOrder => _t('إكمال الطلب', 'Complete Order');
  static String prepareNow(int picked, int total) => _t('التحضير الآن  ($picked/$total)', 'Prepare Now  ($picked/$total)');
  static String get preparationCompletedSuccess => _t('تم إكمال التحضير بنجاح', 'Preparation completed successfully');
  static String get orderCompletedSuccess => _t('تم إكمال الطلب بنجاح', 'Order completed successfully');
  static String get failedToCompleteOrder => _t('فشل إكمال الطلب. حاول مرة أخرى', 'Failed to complete order. Try again');
  static String get orderBarcode => _t('باركود الطلب', 'Order Barcode');
  static String get missing => _t('مفقود', 'Missing');

  // ==================== Picking Screen ====================
  static String get locationVerified => _t('تم التحقق من الموقع ✓', 'Location verified ✓');
  static String picked1Remaining(int remaining) => _t('تم التقاط 1 - المتبقي: $remaining', 'Picked 1 - Remaining: $remaining');
  static String wrongLocation(String location) => _t('موقع خاطئ! المطلوب: $location', 'Wrong location! Required: $location');
  static String get wrongBarcode => _t('باركود خاطئ!', 'Wrong barcode!');
  static String scanLocationFirst(String location) => _t('امسح الموقع أولاً! ($location)', 'Scan location first! ($location)');
  static String get orderCompleted => _t('تم إكمال الطلب!', 'Order Completed!');
  static String get allProductsPrepared => _t('تم تحضير جميع المنتجات بنجاح', 'All products prepared successfully');
  static String get review => _t('مراجعة', 'Review');
  static String get issueReportedSuccess => _t('تم الإبلاغ عن المشكلة بنجاح', 'Issue reported successfully');
  static String get failedToReport => _t('فشل الإبلاغ. حاول مرة أخرى', 'Failed to report. Try again');
  static String get preparation => _t('التحضير', 'Preparation');
  static String get noRemainingProducts => _t('لا توجد منتجات متبقية', 'No remaining products');
  static String get goBack => _t('العودة', 'Go Back');
  static String get manualBarcodeEntry => _t('إدخال باركود يدوي', 'Manual Barcode Entry');
  static String get reportIssue => _t('ابلاغ عن مشكلة', 'Report Issue');
  static String get zebraModeSwitch => _t('تفعيل وضع Zebra', 'Switch to Zebra Mode');
  static String get zebraModeActivated => _t('تم تفعيل وضع Zebra', 'Zebra mode activated');
  static String get honeywellModeSwitch => _t('تفعيل وضع Honeywell', 'Switch to Honeywell Mode');
  static String get honeywellModeActivated => _t('تم تفعيل وضع Honeywell', 'Honeywell mode activated');
  static String get scanLocationFirstHint => _t('امسح الموقع أولا', 'Scan location first');
  static String get picked => _t('الملتقط', 'Picked');
  static String get remaining => _t('المتبقي', 'Remaining');
  static String get required_ => _t('المطلوب', 'Required');
  static String get completed => _t('تم الإكمال!', 'Completed!');
  static String get issueType => _t('نوع المشكلة', 'Issue Type');
  static String get outOfStock => _t('غير متوفر', 'Out of Stock');
  static String get damaged => _t('تالف', 'Damaged');
  static String get expired => _t('منتهي الصلاحية', 'Expired');
  static String get wrongProduct => _t('منتج خاطئ', 'Wrong Product');
  static String get other => _t('أخرى', 'Other');
  static String get submitReport => _t('إرسال البلاغ', 'Submit Report');

  // ==================== Bags Count ====================
  static String get enterBagCount => _t('أدخل عدد الأكياس المستخدمة', 'Enter the number of bags used');
  static String get mustEnterBagCount => _t('يجب إدخال عدد الأكياس', 'Must enter bag count');

  // ==================== Manual Barcode ====================
  static String get enterBarcodeNumber => _t('أدخل رقم الباركود', 'Enter barcode number');
  static String get quantity => _t('الكمية', 'Quantity');

  // ==================== User Form ====================
  static String get editUser => _t('تعديل المستخدم', 'Edit User');
  static String get addNewUser => _t('إضافة مستخدم جديد', 'Add New User');
  static String get name => _t('الاسم', 'Name');
  static String get pleaseEnterName => _t('الرجاء إدخال الاسم', 'Please enter name');
  static String get teamNameForLogin => _t('اسم الفريق (للدخول)', 'Team Name (for login)');
  static String get pleaseEnterTeamName => _t('الرجاء إدخال اسم الفريق', 'Please enter team name');
  static String get passwordMin6 => _t('كلمة المرور يجب أن تكون 6 أحرف على الأقل', 'Password must be at least 6 characters');
  static String get userType => _t('نوع المستخدم', 'User Type');
  static String get picker => _t('بيكر', 'Picker');
  static String get status => _t('الحالة', 'Status');
  static String get active => _t('نشط', 'Active');
  static String get suspended => _t('موقف', 'Suspended');
  static String get saveChanges => _t('حفظ التعديلات', 'Save Changes');
  static String get addUser => _t('إضافة المستخدم', 'Add User');
  static String get userUpdatedSuccess => _t('تم تعديل المستخدم بنجاح', 'User updated successfully');
  static String get userAddedSuccess => _t('تم إضافة المستخدم بنجاح', 'User added successfully');

  // ==================== Account ====================
  static String get failedToLoadData => _t('فشل جلب البيانات. تحقق من اتصال الإنترنت', 'Failed to load data. Check internet connection');
  static String get logout => _t('تسجيل الخروج', 'Logout');
  static String get logoutConfirm => _t('هل أنت متأكد من تسجيل الخروج؟', 'Are you sure you want to logout?');
  static String get onDuty => _t('في الخدمة', 'On Duty');
  static String get offDuty => _t('خارج الخدمة', 'Off Duty');
  static String get todayStats => _t('إحصائيات اليوم', "Today's Statistics");
  static String get completedOrders => _t('الطلبات المكتملة', 'Completed Orders');
  static String get itemsPicked => _t('المنتجات المجمعة', 'Items Picked');
  static String get accountInfo => _t('معلومات الحساب', 'Account Information');
  static String get employeeId => _t('الرقم الوظيفي', 'Employee ID');
  static String get warehouse => _t('المستودع', 'Warehouse');
  static String get zone => _t('المنطقة', 'Zone');
  static String get station => _t('المحطة', 'Station');
  static String get language => _t('اللغة', 'Language');

  // ==================== Change Password ====================
  static String get changePassword => _t('تغيير كلمة المرور', 'Change Password');
  static String get currentPassword => _t('كلمة المرور الحالية', 'Current Password');
  static String get newPassword => _t('كلمة المرور الجديدة', 'New Password');
  static String get confirmNewPassword => _t('تأكيد كلمة المرور الجديدة', 'Confirm New Password');
  static String get newPasswordMismatch => _t('كلمة المرور الجديدة غير متطابقة', "New passwords don't match");
  static String get passwordChangedSuccess => _t('تم تغيير كلمة المرور بنجاح', 'Password changed successfully');
  static String get failedToChangePassword => _t('فشل تغيير كلمة المرور', 'Failed to change password');

  // ==================== QC ====================
  static String get qualityControl => _t('مراقبة الجودة', 'Quality Control');
  static String orderNotFound(String val) => _t('لم يتم العثور على طلب: $val', 'Order not found: $val');
  static String get failedToStartInspection => _t('فشل بدء الفحص', 'Failed to start inspection');
  static String get noInspections => _t('لا توجد فحوصات', 'No inspections');
  static String get orderNumber => _t('رقم الطلب', 'Order Number');
  static String get position => _t('الموقع', 'Position');
  static String get noResults => _t('لا توجد نتائج', 'No results');
  static String bagsCount(int count) => _t('أكياس: $count', 'Bags: $count');
  static String zonesCount(int count) => _t('$count مناطق', '$count zones');
  static String get startInspection => _t('ابدأ الفحص', 'Start Inspection');
  static String get expectedBags => _t('أكياس متوقعة', 'Expected Bags');
  static String get zones => _t('مناطق', 'Zones');
  static String get productsLabel => _t('منتجات', 'Products');
  static String get zonesLabel => _t('المناطق', 'Zones');
  static String completedCount(int count) => _t('$count مكتمل', '$count completed');
  static String problemCount(int count) => _t('$count مشكلة', '$count problem');
  static String get missingBag => _t('كيس مفقود', 'Missing Bag');
  static String get extraBag => _t('كيس زائد', 'Extra Bag');
  static String zoneLabel(String code) => _t('منطقة $code', 'Zone $code');
  static String get orChooseProblemReason => _t('أو اختر سبب المشكلة:', 'Or choose problem reason:');
  static String get preparer => _t('المحضر', 'Preparer');
  static String get problemReason => _t('سبب المشكلة:', 'Problem reason:');
  static String get allZonesInspectedSuccess => _t('تم فحص جميع المناطق بنجاح', 'All zones inspected successfully');
  static String get allZoneStatusesDetermined => _t('تم تحديد حالة جميع المناطق', 'All zone statuses determined');
  static String zonesInspected(int done, int total) => _t('$done من $total مناطق تم فحصها', '$done of $total zones inspected');
  static String get hasProblem => _t('يوجد مشكلة', 'Has Problem');
  static String get orderComplete => _t('الطلب مكتمل', 'Order Complete');
  static String get orderApprovedSuccess => _t('تم اعتماد الطلب بنجاح', 'Order approved successfully');
  static String get failedToApproveInspection => _t('فشل اعتماد الفحص', 'Failed to approve inspection');
  static String get confirmOrderRejection => _t('تأكيد رفض الطلب', 'Confirm Order Rejection');
  static String get rejectedZones => _t('المناطق المرفوضة:', 'Rejected Zones:');
  static String get confirmRejection => _t('تأكيد الرفض', 'Confirm Rejection');
  static String get orderRejected => _t('تم رفض الطلب', 'Order rejected');
  static String get failedToRejectInspection => _t('فشل رفض الفحص', 'Failed to reject inspection');
  static String orderNumberMismatch(String val) => _t('رقم الطلب غير متطابق: $val', 'Order number mismatch: $val');
  static String get orderNumberMismatchSimple => _t('رقم الطلب غير متطابق', 'Order number mismatch');
  static String zoneNotFound(String val) => _t('لم يتم العثور على منطقة: $val', 'Zone not found: $val');
  static String get verifyOrderNumber => _t('تحقق من رقم الطلب', 'Verify order number');
  static String get enterLast6Digits => _t('أدخل آخر 6 أرقام من رقم الطلب', 'Enter last 6 digits of order number');
  static String get last6Digits => _t('آخر 6 أرقام', 'Last 6 digits');
  static String checkNum(String num) => _t('فحص #$num', 'Check #$num');

  // ==================== QC Order Details ====================
  static String get confirmApproval => _t('تأكيد الموافقة', 'Confirm Approval');
  static String get approveOrderQuestion => _t('هل تريد الموافقة على هذا الطلب؟', 'Do you want to approve this order?');
  static String get orderApproved => _t('تمت الموافقة على الطلب بنجاح', 'Order approved successfully');
  static String get rejectOrder => _t('رفض الطلب', 'Reject Order');
  static String get enterRejectionReason => _t('يرجى إدخال سبب الرفض:', 'Please enter rejection reason:');
  static String get rejectionReasonHint => _t('سبب الرفض...', 'Rejection reason...');
  static String get printError => _t('حدث خطأ أثناء الطباعة', 'Print error occurred');
  static String checkOrderNum(String num) => _t('فحص الطلب #$num...', 'Check Order #$num...');
  static String get print_ => _t('طباعة', 'Print');
  static String get district => _t('الحي', 'District');
  static String get time => _t('الوقت', 'Time');
  static String get date => _t('التاريخ', 'Date');
  static String get bags => _t('الأكياس', 'Bags');
  static String get inspectionProgress => _t('تقدم الفحص', 'Inspection Progress');
  static String get note => _t('ملاحظة', 'Note');
  static String get problem => _t('مشكلة', 'Problem');
  static String get approveAndPrint => _t('موافقة وطباعة', 'Approve & Print');
  static String get checkAllProducts => _t('افحص جميع المنتجات', 'Check all products');
  static String get damagedProduct => _t('منتج تالف', 'Damaged product');
  static String get wrongQuantity => _t('كمية خاطئة', 'Wrong quantity');
  static String get wrongProductItem => _t('منتج خاطئ', 'Wrong product');
  static String get missingProduct => _t('منتج مفقود', 'Missing product');
  static String reportIssueFor(String name) => _t('الإبلاغ عن مشكلة: $name', 'Report issue: $name');
  static String reported(String label) => _t('تم الإبلاغ عن: $label', 'Reported: $label');
  static String noteFor(String name) => _t('ملاحظة: $name', 'Note: $name');
  static String get enterNoteHere => _t('أدخل ملاحظتك هنا...', 'Enter your note here...');

  // ==================== Positions Grid ====================
  static String get needsCheck => _t('يحتاج فحص', 'Needs Check');
  static String get inspectionInProgress => _t('جاري الفحص', 'In Progress');
  static String get empty => _t('فارغ', 'Empty');

  // ==================== Master Picker ====================
  static String get masterPickerDashboard => _t('لوحة الماستر بيكر', 'Master Picker Dashboard');
  static String get scanOrderBarcode => _t('امسح باركود الطلب...', 'Scan order barcode...');
  static String get noTasksCurrently => _t('لا توجد مهام حالياً', 'No tasks currently');
  static String noResultsFor(String query) => _t('لا توجد نتائج لـ "$query"', 'No results for "$query"');
  static String zonePrefix(String name) => _t('زون $name', 'Zone $name');
  static String get assignedStatus => _t('معيّن', 'Assigned');
  static String get zoneStats => _t('إحصائيات الزونات', 'Zone Stats');

  // ==================== Task Detail (Master) ====================
  static String get pickerLabel => _t('البيكر', 'Picker');
  static String get itemPicked => _t('تم الالتقاط', 'Picked');
  static String get partiallyPicked => _t('التقاط جزئي', 'Partially Picked');
  static String get location => _t('الموقع', 'Location');
  static String get productBarcode => _t('باركود المنتج', 'Product Barcode');

  // ==================== Pending Exceptions ====================
  static String get pendingExceptions => _t('الاستثناءات المعلقة', 'Pending Exceptions');
  static String get noPendingExceptions => _t('لا توجد استثناءات معلقة', 'No pending exceptions');
  static String get exceptionAccepted => _t('تم قبول الاستثناء', 'Exception accepted');
  static String get exceptionRejected => _t('تم رفض الاستثناء', 'Exception rejected');
  static String get operationFailed => _t('فشل العملية', 'Operation failed');
  static String get shortQuantity => _t('كمية ناقصة', 'Short Quantity');

  // ==================== Model Display Names ====================
  static String get roleSupervisor => _t('سوبر فايزر', 'Supervisor');
  static String get roleQC => _t('مراقب جودة', 'QC Inspector');
  static String get rolePicker => _t('بيكر', 'Picker');
  static String get statusActive => _t('نشط', 'Active');
  static String get statusInactive => _t('غير نشط', 'Inactive');
  static String get statusBusy => _t('مشغول', 'Busy');

  // ==================== QC Status Display Names ====================
  static String get qcUnspecified => _t('غير محدد', 'Unspecified');
  static String get qcPending => _t('قيد الانتظار', 'Pending');
  static String get qcInProgress => _t('جاري الفحص', 'In Progress');
  static String get qcPassed => _t('ناجح', 'Passed');
  static String get qcFailed => _t('مرفوض', 'Failed');
  static String get qcOverridden => _t('تم التجاوز', 'Overridden');

  // ==================== Auth/API ====================
  static String get loginFailed => _t('فشل تسجيل الدخول', 'Login failed');
  static String get serverConnectionFailed => _t('فشل الاتصال بالخادم. تحقق من اتصال الإنترنت', 'Server connection failed. Check internet connection');
  static String get unexpectedError => _t('حدث خطأ غير متوقع', 'An unexpected error occurred');
}
